#!/usr/bin/python

import sys
import os
import json

# we need the ldmx configuration package to construct the object

from LDMX.Framework import ldmxcfg

# first, we define the process, which must have a name which identifies this
# processing pass ("pass name").
# the other two pass names refer to those of the input files which will be combined in this job.
thisPassName="v3.0.0" #overlay" 
simPassName="v12"
nElectrons=1
p=ldmxcfg.Process( thisPassName )

#import all processors

# Ecal hardwired/geometry stuff
from LDMX.Ecal import EcalGeometry
import LDMX.Ecal.ecal_hardcoded_conditions
egeom = EcalGeometry.EcalGeometryProvider.getInstance()

#Hcal hardwired/geometry stuff                                                                                                                    
from LDMX.Hcal import HcalGeometry
import LDMX.Hcal.hcal_hardcoded_conditions
hgeom = HcalGeometry.HcalGeometryProvider.getInstance()

from LDMX.Ecal import digi as eDigi
from LDMX.Ecal import vetos
from LDMX.Hcal import digi as hDigi
                                                                                                      
from LDMX.TrigScint.trigScint import TrigScintDigiProducer
from LDMX.TrigScint.trigScint import TrigScintClusterProducer
from LDMX.TrigScint.trigScint import trigScintTrack

from LDMX.Recon.electronCounter import ElectronCounter
from LDMX.Recon.simpleTrigger import simpleTrigger


p.run = RUNNUMBER
p.inputFiles =[ INPUTNAME ]

# set the maximum number of events to process
#p.maxEvents = 100

#rereco everything. 
#. start with TS
tsDigisTag  =TrigScintDigiProducer.tagger()
tsDigisUp  =TrigScintDigiProducer.up()
tsDigisDown  =TrigScintDigiProducer.down()
#make sure to pick up the right pass 
tsDigisTag.input_pass_name = simPassName 
tsDigisUp.input_pass_name = tsDigisTag.input_pass_name
tsDigisDown.input_pass_name = tsDigisTag.input_pass_name
#clustering
tsClustersTag  =TrigScintClusterProducer.tagger()
tsClustersUp  =TrigScintClusterProducer.up()
tsClustersDown  =TrigScintClusterProducer.down()
tsClustersTag.input_pass_name = thisPassName 
tsClustersUp.input_pass_name = tsClustersTag.input_pass_name
tsClustersDown.input_pass_name = tsClustersTag.input_pass_name
tsClustersTag.verbosity = 0
tsClustersUp.verbosity = tsClustersTag.verbosity
tsClustersDown.verbosity = tsClustersTag.verbosity

#and tracking 
trigScintTrack.delta_max = 0.75
trigScintTrack.verbosity = 0
trigScintTrack.input_pass_name = thisPassName

#and Ecal 
ecalReDigi   =eDigi.EcalDigiProducer('ecalReDigi')
ecalReReco   =eDigi.EcalRecProducer('ecalReRecon')
ecalRerecoVeto   =vetos.EcalVetoProcessor('ecalVetoRerecoBDT')
#these should all be the defaults, it's just rereco
#ecalReReco.digiCollName   = ecalReDigi.digiCollName
#ecalReReco.simHitCollName = ecalReReco.simHitCollName+overlayStr
#ecalReReco.recHitCollName = ecalReReco.recHitCollName+overlayStr
#here the pass name is extremely important
ecalReDigi.inputPassName  = simPassName #start from old sim
ecalReReco.simHitPassName  = simPassName #rereco on this digi pass
ecalReReco.digiPassName = thisPassName 
ecalRerecoVeto.rec_pass_name = thisPassName

# and Hcal
hcalReDigi   =hDigi.HcalDigiProducer('hcalReDigis')
hcalReReco   =hDigi.HcalRecProducer('hcalReRecon')
hcalReDigi.inputPassName  = simPassName  #start from old sim
hcalReReco.simHitPassName  = simPassName 
hcalReReco.digiPassName = thisPassName   #rereco on this digi pass

# electron counter so simpletrigger doesn't crash 
eCount = ElectronCounter( nElectrons, "ElectronCounter") # first argument is number of electrons in simulation 
eCount.use_simulated_electron_number = True #False
eCount.input_pass_name=thisPassName

#trigger skim
simpleTrigger.start_layer= 0   #make sure it doesn't start from 1 (old default bug)
simpleTrigger.input_pass=thisPassName
p.skimDefaultIsDrop()
p.skimConsider("simpleTrigger")

#BDT seems to crash
#p.sequence = [ecalReDigi, ecalReReco, ecalRerecoVeto, tsDigisTag, tsDigisUp, tsDigisDown, tsClustersTag, tsClustersUp, tsClustersDown, trigScintTrack, eCount, simpleTrigger, hcalReDigi, hcalReReco] 
p.sequence = [ecalReDigi, ecalReReco, tsDigisTag, tsDigisUp, tsDigisDown, tsClustersTag, tsClustersUp, tsClustersDown, trigScintTrack, eCount, simpleTrigger, hcalReDigi, hcalReReco] 


p.outputFiles= [ "simoutput.root" ]

#drop some scoring plane hits to make space, and old ecal digi+reco; only the veto and trigger results remain from the pure PN hits. also, keep sim hits for now, to be able to rerun reco/overlay if needed. 
#p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits", "drop EcalDigis_"+simPassName,  "drop EcalRecHits_"+simPassName,  "drop HcalRecHits_"+simPassName  ] 
#p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits", 
p.keep = ["drop EcalDigis_v12",  "drop EcalRecHits_"+simPassName,  "drop HcalRecHits_"+simPassName, "drop trigScintDigisTag_"+simPassName, "drop trigScintDigisUp_"+simPassName, "drop trigScintDigisDn_"+simPassName, "drop TriggerPadTaggerClusters_"+simPassName, "drop TriggerPadUpClusters_"+simPassName, "drop TriggerPadDownClusters_"+simPassName, "drop EcalVeto_"+simPassName  ] 

p.termLogLevel = 0  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.                                                            
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)    
logEvents=20
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

# if it's not set, it's because we're doing pileup, right, and expect on order 10k events per job
if not p.maxEvents: 
     p.logFrequency = 1000

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


