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
simPassName="v12"
pileupPassName="pileup"
p=ldmxcfg.Process( thisPassName )

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
                                  
                                                                                                 
#p.run = RUNNUMBER
inputName= sys.argv[1] #"inclusive_1e_upstream_4GeV.root" #
p.inputFiles =[ inputName ]

pileupFileName = "pileup_run1_1e_upstream_4GeV.root" #sys.argv[2] # 


overlay=OverlayProducer( pileupFileName ) # "pileup_run1_1e_upstream_4GeV.root" ) #"pileup_1e_upstream_4GeV.root" ) #

overlay.passName = simPassName
overlay.overlayPassName = pileupPassName
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
#p.maxEvents = 100

overlayStr="Overlay"
                                                            
tsDigisTag  =TrigScintDigiProducer.tagger()
tsDigisTag.input_collection = tsDigisTag.input_collection+overlayStr
tsDigisUp  =TrigScintDigiProducer.up()
tsDigisUp.input_collection = tsDigisUp.input_collection+overlayStr
tsDigisDown  =TrigScintDigiProducer.down()
tsDigisDown.input_collection = tsDigisDown.input_collection+overlayStr

#make sure to pick up the right pass 
tsDigisTag.input_pass_name = thisPassName 
tsDigisUp.input_pass_name = tsDigisTag.input_pass_name
tsDigisDown.input_pass_name = tsDigisTag.input_pass_name

ecalDigi   =digi.EcalDigiProducer('EcalDigis'+overlayStr)
ecalReco   =digi.EcalRecProducer('ecalRecon'+overlayStr)

#add overlay string to collection names to be super clear
ecalDigi.inputCollName  = ecalDigi.inputCollName+overlayStr
ecalDigi.digiCollName   = ecalDigi.digiCollName+overlayStr
# pick this name up immediately in reco 
ecalReco.digiCollName   = ecalDigi.digiCollName
ecalReco.recHitCollName = ecalReco.recHitCollName+overlayStr
ecalReco.simHitCollName = ecalReco.simHitCollName+overlayStr

#explicitly set the pass here too 
ecalDigi.inputPassName  = thisPassName
ecalReco.inputPassName  = thisPassName

# tracker stuff is all hardwired, so, we can run the non-overlaid versions, but that's it
# same for ecal bdt input collection name, and for hcal digi/reconstruction.

#so, just run the overlay-enabled processors. the rest is there from original reco. 
p.sequence.extend( [ecalDigi, ecalReco, tsDigisTag, tsDigisUp, tsDigisDown ])

p.outputFiles= [ "simoutput.root" ]

#drop some scoring plane hits to make space, and old ecal digi+reco; only the veto and trigger results remain from the pure PN hits. also, keep sim hits for now, to be able to rerun reco/overlay if needed. 
p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits", "drop EcalDigis_"+simPassName,  "drop EcalRecHits_"+simPassName ] 

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.                                                            
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)    
logEvents=20
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


