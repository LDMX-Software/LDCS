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
simPassName="signal"
pileupPassName="pileup"
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
from LDMX.TrigScint.trigScint import trigScintTrack

from LDMX.Recon.overlay import OverlayProducer
                                                                                                                                   
p.run = RUNNUMBER
p.inputFiles =[ INPUTNAME ]
pileupFileName = PILEUPFILENAME 

overlay=OverlayProducer( pileupFileName ) 
overlay.passName = simPassName
overlay.overlayPassName = pileupPassName
overlay.totalNumberOfInteractions = 2.
overlay.doPoissonIntime = False
overlay.doPoissonOutoftime = False
overlay.nEarlierBunchesToSample = 0
overlay.nLaterBunchesToSample = 0
overlay.timeSpread = 0.     # <-- a fix pileup time offset is easier to see than a Gaussian distribution 
overlay.timeMean   = 0.     # <-- here set it to no time shift whatsoever
overlay.overlayCaloHitCollections=[ "TriggerPadTaggerSimHits", "TriggerPadUpSimHits", "TriggerPadDownSimHits", "TargetSimHits", "EcalSimHits", "HcalSimHits"]
overlay.overlayTrackerHitCollections=[ "TaggerSimHits", "RecoilSimHits" ]
overlay.verbosity=0

p.sequence = [ overlay ]

# set the maximum number of events to process
#p.maxEvents = 10

overlayStr="Overlay"
                                                            
tsDigisTag  =TrigScintDigiProducer.tagger()
tsDigisTag.input_collection = tsDigisTag.input_collection+overlayStr
tsDigisTag.output_collection = tsDigisTag.output_collection+overlayStr
tsDigisUp  =TrigScintDigiProducer.up()
tsDigisUp.input_collection = tsDigisUp.input_collection+overlayStr
tsDigisUp.output_collection = tsDigisUp.output_collection+overlayStr
tsDigisDown  =TrigScintDigiProducer.down()
tsDigisDown.input_collection = tsDigisDown.input_collection+overlayStr
tsDigisDown.output_collection = tsDigisDown.output_collection+overlayStr

#make sure to pick up the right pass 
tsDigisTag.input_pass_name = thisPassName 
tsDigisUp.input_pass_name = tsDigisTag.input_pass_name
tsDigisDown.input_pass_name = tsDigisTag.input_pass_name

tsClustersTag  =TrigScintClusterProducer.tagger()
tsClustersTag.input_collection = tsDigisTag.output_collection
tsClustersUp  =TrigScintClusterProducer.up()
tsClustersUp.input_collection = tsDigisUp.output_collection
tsClustersDown  =TrigScintClusterProducer.down()
tsClustersDown.input_collection = tsDigisDown.output_collection

#make sure to pick up the right pass 
tsClustersTag.input_pass_name = thisPassName 
tsClustersUp.input_pass_name = tsClustersTag.input_pass_name
tsClustersDown.input_pass_name = tsClustersTag.input_pass_name

trigScintTrack.input_pass_name = thisPassName

#--- overlay ecal digi/reco
ecalDigi   =eDigi.EcalDigiProducer('ecalDigi')
ecalReco   =eDigi.EcalRecProducer('ecalRecon')
#ecalVeto   =vetos.EcalVetoProcessor('ecalVetoBDT')

ecalDigi.inputCollName  = ecalDigi.inputCollName+overlayStr
ecalDigi.digiCollName   = ecalDigi.digiCollName+overlayStr
# pick this name up immediately in reco 
ecalReco.digiCollName   = ecalDigi.digiCollName
ecalReco.simHitCollName = ecalReco.simHitCollName+overlayStr
ecalReco.recHitCollName = ecalReco.recHitCollName+overlayStr
#now pick this up in veto processor
#ecalVeto.rec_coll_name  = ecalReco.recHitCollName
#ecalVeto.collection_name  = ecalVeto.collection_name+overlayStr
#explicitly set the pass here too 
ecalDigi.inputPassName  = thisPassName
ecalReco.simHitPassName  = thisPassName
ecalReco.digiPassName = thisPassName
#ecalVeto.rec_pass_name = thisPassName

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


# run ecal veto only on rereco, until we have a release where all input names are configurable
# for hcal veto: nothing configurable yet (not even pass name) so skip it  
p.sequence.extend( [ecalDigi, ecalReco, tsDigisTag, tsDigisUp, tsDigisDown, tsClustersTag, tsClustersUp, tsClustersDown, trigScintTrack, hcalDigi, hcalReco] ) 

p.outputFiles= [ "simoutput.root" ]

#drop some scoring plane hits to make space, and old ecal digi+reco; only the veto and trigger results remain from the pure PN hits. also, keep sim hits for now, to be able to rerun reco/overlay if needed. 
#p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits", "drop EcalDigis_"+simPassName,  "drop EcalRecHits_"+simPassName,  "drop HcalRecHits_"+simPassName  ] 
#p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.                                                            
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)    
logEvents=20
# if it's not set, it's because we're doing pileup, right, and expect on order 10k events per job
if not p.maxEvents: 
     p.logFrequency = 1000
elif p.maxEvents < logEvents :
     logEvents = p.maxEvents  #less than 20 events, so log all 
     p.logFrequency = int( p.maxEvents/logEvents )
else :
     p.logFrequency = int( p.maxEvents/logEvents )


json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


