#!/bin/python3

import os
import sys
import json

from LDMX.Framework import ldmxcfg

# set a 'pass name'
p=ldmxcfg.Process("sim")

#import all processors
from LDMX.SimCore import generators
from LDMX.SimCore import simulator
from LDMX.Biasing import filters

# Ecal hardwired/geometry stuff
import LDMX.Ecal.EcalGeometry
import LDMX.Ecal.ecal_hardcoded_conditions

from LDMX.Ecal import digi
from LDMX.Ecal import vetos
from LDMX.Hcal import hcal
from LDMX.EventProc.simpleTrigger import simpleTrigger 
from LDMX.EventProc.trackerHitKiller import trackerHitKiller
#from LDMX.TrigScint.trigScint import TrigScintDigiProducer

from LDMX.Detectors.makePath import *

from LDMX.SimCore import simcfg

#
# Instantiate the simulator.
#
sim = simulator.simulator("mySim")

#
# Set the path to the detector to use. 
#
sim.setDetector( 'ldmx-det-v12', True  )
sim.scoringPlanes = makeScoringPlanesPath('ldmx-det-v12')

#
# Set run parameters
#
p.run = RUNNUMBER
sim.description = "8 GeV ECal photo-nuclear, xsec bias 550"
sim.randomSeeds = [ SEED1 , SEED2 ]
sim.beamSpotSmear = [20., 80., 0]

#
# Fire an electron upstream of the tagger tracker
#
sim.generators = [ generators.single_8gev_e_upstream_tagger() ]


#
# Enable and configure the biasing
#
sim.biasingOn(True)
sim.biasingConfigure('photonNuclear', 'ecal', 5000., 550)

#
# Configure the sequence in which user actions should be called.
#
sim.actions = [ filters.TaggerVetoFilter(),
                                    filters.TargetBremFilter(),
                                    filters.EcalProcessFilter(), 
                                    filters.TrackProcessFilter.photo_nuclear() ]

findableTrack = ldmxcfg.Producer("findable", "ldmx::FindableTrackProcessor", "EventProc")

trackerVeto = ldmxcfg.Producer("trackerVeto", "ldmx::TrackerVetoProcessor", "EventProc")


ecalDigi   =digi.EcalDigiProducer('EcalDigis')
ecalSim2Rec=digi.EcalRecProducer('ecalRecon')
ecalVeto   =vetos.EcalVetoProcessor('ecalVetoBDT')
hcalDigis  =hcal.HcalDigiProducer('hcalRecon')
hcalVeto   =hcal.HcalVetoProcessor('hcalVeto')

simpleTrigger.threshold = 8000.0 - 4840.0

from LDMX.DQM import dqm
hcalDQM= dqm.HCalDQM() 
pnDQM=dqm.PhotoNuclearDQM()
trackerDQM=dqm.RecoilTrackerDQM()


#p.sequence=[ sim, ecalDigi, ecalSim2Rec, ecalVeto, hcalDigis, hcalVeto, tsDigisTag, tsDigisUp, tsDigisDown, trackerHitKiller, simpleTrigger, findableTrack, trackerVeto, pnDQM, hcalDQM, trackerDQM ]
p.sequence=[ sim, ecalDigi, ecalSim2Rec, ecalVeto, hcalDigis, hcalVeto, tsDigisTag, tsDigisUp, tsDigisDown, trackerHitKiller, simpleTrigger, findableTrack,  pnDQM, hcalDQM, trackerDQM ]
#tracker veto still hardwired at 1.2 GeV and kills way too much, so it's becomes pointless to look at DQM if it's run 


p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]
p.outputFiles=["simoutput.root"]
p.histogramFile = "histo.root"

p.maxEvents = 10000

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


     
