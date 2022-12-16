#!/usr/bin/python

import sys
import os
import json

# we need the ldmx configuration package to construct the object

from LDMX.Framework import ldmxcfg

# first, we define the process, which must have a name which identifies this
# processing pass ("pass name").
# the other two pass names refer to those of the input files which will be combined in this job.
thisPassName="overlay" 
simPassName="sim"
pileupPassName="sim" #pileup"
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

from LDMX.Recon.simpleTrigger import simpleTrigger
                                                                                                      
from LDMX.TrigScint.trigScint import TrigScintDigiProducer
from LDMX.TrigScint.trigScint import TrigScintClusterProducer


from LDMX.Recon.overlay import OverlayProducer
                                  
                                                                                                 
p.run = RUNNUMBER
p.inputFiles =[ INPUTNAME ]

pileupFileName = PILEUPFILENAME 


overlay=OverlayProducer( pileupFileName ) # "pileup_run1_1e_upstream_4GeV.root" ) #"pileup_1e_upstream_4GeV.root" ) #

overlay.passName = simPassName
overlay.overlayPassName = pileupPassName
overlay.totalNumberOfInteractions = 2.
overlay.doPoissonIntime = False
overlay.doPoissonOutoftime = False
overlay.nEarlierBunchesToSample = 0
overlay.nLaterBunchesToSample = 0
overlay.timeSpread = 0.     # <-- a fix pileup time offset is easier to see than a Gaussian distribution 
overlay.timeMean   = 0.     # <-- here set it to no time shift whatsoever
tsSimColls=[ "TriggerPadTaggerSimHits", "TriggerPadUpSimHits", "TriggerPadDownSimHits" ]
overlay.overlayCaloHitCollections=tsSimColls+["TargetSimHits", "EcalSimHits", "HcalSimHits"]
overlay.overlayTrackerHitCollections=[ "TaggerSimHits", "RecoilSimHits" ]
overlay.verbosity=0


p.sequence = [ overlay ]

# set the maximum number of events to process
#p.maxEvents = 100

overlayStr="Overlay"
                                                            
tsDigisTag =TrigScintDigiProducer.pad2()
tsDigisTag.input_collection  = tsSimColls[0]+overlayStr
tsDigisUp  =TrigScintDigiProducer.pad3()
tsDigisUp.input_collection   = tsSimColls[1]+overlayStr #tsDigisUp.input_collection+overlayStr
tsDigisDown=TrigScintDigiProducer.pad1()
tsDigisDown.input_collection = tsSimColls[2]+overlayStr #tsDigisDown.input_collection+overlayStr

#make sure to pick up the right pass 
tsDigisTag.input_pass_name = thisPassName 
tsDigisUp.input_pass_name = tsDigisTag.input_pass_name
tsDigisDown.input_pass_name = tsDigisTag.input_pass_name


tsClustersDown  =TrigScintClusterProducer.pad1()
tsClustersTag  =TrigScintClusterProducer.pad2()
tsClustersUp  =TrigScintClusterProducer.pad3()

if "v12" in detector :
     tsClustersTag.pad_time = -2.
     tsClustersUp.pad_time = 0.
     tsClustersDown.pad_time = 0.

tsClustersDown.input_collection = tsDigisDown.output_collection
tsClustersTag.input_collection = tsDigisTag.output_collection
tsClustersUp.input_collection = tsDigisUp.output_collection

#make sure to pick up the right pass                                                                                                                  
tsClustersTag.input_pass_name = thisPassName
tsClustersUp.input_pass_name = tsClustersTag.input_pass_name
tsClustersDown.input_pass_name = tsClustersTag.input_pass_name

trigScintTrack.input_pass_name = thisPassName
trigScintTrack.seeding_collection = tsClustersTag.output_collection


#--- first: overlay ecal digi/reco
ecalDigi   =eDigi.EcalDigiProducer('ecalDigi')
ecalReco   =eDigi.EcalRecProducer('ecalRecon')
ecalVeto   =vetos.EcalVetoProcessor('ecalVetoBDT')

ecalDigi.inputCollName  = ecalDigi.inputCollName+overlayStr
ecalDigi.digiCollName   = ecalDigi.digiCollName+overlayStr
# pick this name up immediately in reco 
ecalReco.digiCollName   = ecalDigi.digiCollName
ecalReco.simHitCollName = ecalReco.simHitCollName+overlayStr
ecalReco.recHitCollName = ecalReco.recHitCollName+overlayStr
#now pick this up in veto processor
ecalVeto.rec_coll_name  = ecalReco.recHitCollName
ecalVeto.collection_name  = ecalVeto.collection_name+overlayStr
#explicitly set the pass here too 
ecalDigi.inputPassName  = thisPassName
ecalReco.simHitPassName  = thisPassName
ecalReco.digiPassName = thisPassName
ecalVeto.rec_pass_name = thisPassName

#hcal digi chain for overlay collections
hcalDigi   =hDigi.HcalDigiProducer('hcalDigis')
hcalDigi.inputCollName  = hcalDigi.inputCollName+overlayStr
hcalDigi.digiCollName   = hcalDigi.digiCollName+overlayStr
hcalReco   =hDigi.HcalRecProducer('hcalRecon')
hcalReco.digiCollName   = hcalDigi.digiCollName
hcalReco.simHitCollName = hcalReco.simHitCollName+overlayStr
hcalReco.recHitCollName = hcalReco.recHitCollName+overlayStr
#explicitly set the pass here too
hcalDigi.inputPassName  = thisPassName
hcalReco.simHitPassName  = thisPassName
hcalReco.digiPassName = thisPassName

                                            
eCount = ElectronCounter( 2, "ElectronCounter") # first argument is number of electrons in simulation                                                 
eCount.use_simulated_electron_number = False
eCount.input_pass_name=thisPassName
eCount.input_collection="TriggerPadTracksY"

#trigger setup, no skim                                                                                                                               
simpleTrigger.input_collection=ecalReco.recHitCollName 
simpleTrigger.input_pass=thisPassName
simpleTrigger.trigger_collection="2eTrigger"
simpleTrigger.trigger_thresholds=[1400., 4800., 8400, 1180.]

#p.skimDefaultIsDrop()                                                                                                                                
#p.skimConsider("simpleTrigger")                                                                          


#run ecal veto only on rereco, until we have a release where all input names are configurable. same for hcal veto: nothing configurable yet (not even pass name) so skip it  
p.sequence.extend( [ecalDigi, ecalReco, tsDigisTag, tsDigisUp, tsDigisDown, tsClustersTag, tsClustersUp, tsClustersDown, trigScintTrack, eCount, simpleTrigger, hcalDigi, hcalReco ] )


p.outputFiles= [ "simoutput.root" ]

#drop some scoring plane hits to make space,  keep sim hits for now, to be able to rerun reco/overlay if needed. 
p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.                                                            
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


