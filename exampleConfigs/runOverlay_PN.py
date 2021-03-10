#!/usr/bin/python

import sys
import os

# we need the ldmx configuration package to construct the object

from LDMX.Framework import ldmxcfg

# first, we define the process, which must have a name which identifies this
# processing pass ("pass name").
#p=ldmxcfg.Process("sim")
p=ldmxcfg.Process("overlay")

#import all processors                                                                                                                                                       

p.run = 2

#pull in input file

inputName= sys.argv[1]
p.inputFiles =[ inputName ]


#from LDMX.EventProc import overlay 
from LDMX.EventProc.overlay import OverlayProducer
overlay=OverlayProducer( "pileup_run1_1e_upstream_4GeV.root" ) #"pileup_1e_upstream_4GeV.root" ) #
#overlay = ldmxcfg.Producer("overlay", "ldmx::OverlayProducer", "EventProc")

overlay.passName = "v12"
overlay.overlayPassName = "pileup"
overlay.totalNumberOfInteractions = 2.
overlay.doPoisson = False
overlay.timeSpread = 0.     # <-- a fix pileup time offset is easier to see than a Gaussian distribution 
overlay.timeMean   = 0.     # <-- here set it to no time shift whatsoever
#overlay.overlayProcessName = "inclusive"
overlay.overlayCaloHitCollections=[ "TriggerPadTaggerSimHits", "TriggerPadUpSimHits", "TriggerPadDownSimHits", "TargetSimHits", "EcalSimHits", "HcalSimHits"]
overlay.overlayTrackerHitCollections=[ "TaggerSimHits", "RecoilSimHits" ]
overlay.verbosity=1


#p.sequence = [ mySim, overlay ]
p.sequence = [ overlay ]


# set the maximum number of events to process
p.maxEvents=10000

# Ecal hardwired/geometry stuff                                                                                                                                                       
import LDMX.Ecal.EcalGeometry
import LDMX.Ecal.ecal_hardcoded_conditions

from LDMX.Ecal import digi
from LDMX.Ecal import vetos
from LDMX.Hcal import hcal
from LDMX.EventProc.simpleTrigger import simpleTrigger
from LDMX.EventProc.trackerHitKiller import trackerHitKiller
from LDMX.TrigScint.trigScint import TrigScintDigiProducer

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
#ecalDigi.digiCollName   = ecalDigi.digiCollName+overlayStr
#ecalReco.digiCollName   = ecalReco.digiCollName+overlayStr
#ecalReco.recHitCollName = ecalReco.recHitCollName+overlayStr
ecalReco.simHitCollName = ecalReco.simHitCollName+overlayStr
ecalReco.digiPassName = "overlay"
ecalVeto.rec_pass_name = "overlay"

                                       
p.sequence.extend( [ecalDigi, ecalReco, ecalVeto, tsDigisTag, tsDigisUp, tsDigisDown] )


p.inputFiles= [ inputName ]
outputName=sys.argv[2]
#outputName=outName.replace(".root", "_with-1e-overlay_recon.root")
p.outputFiles= [ outputName ]


# Utility function to interpret and print out the configuration to the screen
print(p)
