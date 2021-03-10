#!/usr/bin/python

import sys
import os
import json

# we need the ldmx configuration package to construct the object

from LDMX.Framework import ldmxcfg

# first, we define the process, which must have a name which identifies this
# processing pass ("pass name").
#p=ldmxcfg.Process("sim")
p=ldmxcfg.Process("overlay")

#import all processors

# Ecal hardwired/geometry stuff
import LDMX.Ecal.EcalGeometry
import LDMX.Ecal.ecal_hardcoded_conditions

from LDMX.Ecal import digi
from LDMX.Ecal import vetos
from LDMX.Hcal import hcal
from LDMX.EventProc.simpleTrigger import simpleTrigger
from LDMX.EventProc.trackerHitKiller import trackerHitKiller
from LDMX.TrigScint.trigScint import TrigScintDigiProducer
from LDMX.EventProc.overlay import OverlayProducer
                                  
                                                                                                 
p.run = RUNNUMBER
p.inputFiles =[ INPUTNAME ]

pileupFileName = PILEUPFILE


overlay=OverlayProducer( pileupFileName ) # "pileup_run1_1e_upstream_4GeV.root" ) #"pileup_1e_upstream_4GeV.root" ) #

overlay.overlayPassName = "sim" #pileup"
overlay.totalNumberOfInteractions = 2.
overlay.doPoisson = False
overlay.timeSpread = 0.     # <-- a fix pileup time offset is easier to see than a Gaussian distribution 
overlay.timeMean   = 0.     # <-- here set it to no time shift whatsoever
#overlay.overlayProcessName = "inclusive"
overlay.overlayCaloHitCollections=[ "TriggerPadTaggerSimHits", "TriggerPadUpSimHits", "TriggerPadDownSimHits", "TargetSimHits", "EcalSimHits", "HcalSimHits"]
overlay.overlayTrackerHitCollections=[ "TaggerSimHits", "RecoilSimHits" ]
overlay.verbosity=1

p.sequence = [ overlay ]

# set the maximum number of events to process

overlayStr="Overlay"
                                                            
tsDigisTag  =TrigScintDigiProducer.tagger()
tsDigisTag.input_collection = tsDigisTag.input_collection+overlayStr
tsDigisUp  =TrigScintDigiProducer.up()
tsDigisUp.input_collection = tsDigisUp.input_collection+overlayStr
tsDigisDown  =TrigScintDigiProducer.down()
tsDigisDown.input_collection = tsDigisDown.input_collection+overlayStr

ecalDigi   =digi.EcalDigiProducer('EcalDigis')
ecalReco   =digi.EcalRecProducer('ecalRecon')
ecalVeto   =vetos.EcalVetoProcessor('ecalVetoBDT')

ecalDigi.inputCollName  = ecalDigi.inputCollName+overlayStr
ecalReco.recHitCollName = ecalReco.recHitCollName+overlayStr
ecalReco.simHitCollName = ecalReco.simHitCollName+overlayStr


# and then a round of ecal digi+reco and veto for getting the ecal BDT results for the non-overlaid collections
ecalPNDigi   =digi.EcalDigiProducer('EcalPNDigis')
ecalPNReco   =digi.EcalRecProducer('ecalPNRecon')
ecalPNVeto   =vetos.EcalVetoProcessor('ecalPNVetoBDT')

#need to identify the non-overlaid, simulated collections 
simStr="PN"
ecalPNDigi.digiCollName   = ecalPNDigi.digiCollName+simStr
ecalPNReco.digiCollName   = ecalPNDigi.digiCollName

#here we can assume the standard names, bcs overlay collections have "Overlay" in the names
ecalPNDigi.inputCollName  = ecalPNDigi.inputCollName
ecalPNReco.simHitCollName = ecalPNReco.simHitCollName

ecalPNVeto.rec_coll_name = ecalPNReco.recHitCollName
ecalPNVeto.collection_name = ecalPNVeto.collection_name+simStr


#tracker stuff is all hardwired, so, we can run the non-overlaid versions, but that's it
findableTrack = ldmxcfg.Producer("findable", "ldmx::FindableTrackProcessor", "EventProc")
trackerVeto = ldmxcfg.Producer("trackerVeto", "ldmx::TrackerVetoProcessor", "EventProc")


# NOTE that the hcal digi and veto don't have configurable input collection names, so, these are the non-overlaid collections, and they should not be kept (but the veto is still interesting)

p.sequence.extend( [ecalDigi, ecalReco, ecalVeto, tsDigisTag, tsDigisUp, tsDigisDown, trackerHitKiller, simpleTrigger, findableTrack, trackerVeto, hcal.HcalDigiProducer(), hcal.HcalVetoProcessor() ] )

p.outputFiles= [ "simoutput.root" ]

p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits", "drop "+ecalPNDigi.digiCollName,  "drop "+ecalPNReco.recHitCollName, "drop hcalDigis" ]


p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.                                                            
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)     

logEvents=20
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


