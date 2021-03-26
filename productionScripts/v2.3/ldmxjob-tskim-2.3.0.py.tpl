#!/bin/python

import os
import sys
import json

from LDMX.Framework import ldmxcfg

# set a 'pass name'; avoid sim or reco(n) as they are apparently overused
p=ldmxcfg.Process("tskim")

#import all processors

# Ecal hardwired/geometry stuff
#import LDMX.Ecal.EcalGeometry
#import LDMX.Ecal.ecal_hardcoded_conditions


#
# Set run parameters
#
#p.inputFiles = [ "mc_v12-4GeV-1e-ecal_photonuclear_run1_t1611248262.root" ]
p.inputFiles = [ INPUTNAME ]
p.run = RUNNUMBER


#
# Configure the sequence in which user actions should be called.
#


p.skimDefaultIsKeep=False
p.skimRules=[ "simpleTrigger" ]
#p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]

#add these to do something apart from just skimming
from LDMX.TrigScint.trigScint import TrigScintClusterProducer
from LDMX.TrigScint.trigScint import trigScintTrack

trigScintTrack.delta_max = 0.75

p.sequence=[  TrigScintClusterProducer.tagger(),TrigScintClusterProducer.up(), TrigScintClusterProducer.down(), trigScintTrack ]

p.outputFiles=["simoutput.root"]


p.termLogLevel = 0  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


     
