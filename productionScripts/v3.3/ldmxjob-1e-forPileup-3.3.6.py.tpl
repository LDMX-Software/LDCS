#!/bin/python

import sys
import os
import json

# we need the ldmx configuration package to construct the object

from LDMX.Framework import ldmxcfg

# set a 'pass name'
passName="sim"
p=ldmxcfg.Process(passName)

#import all processors
from LDMX.SimCore import generators
from LDMX.SimCore import simulator
from LDMX.Biasing import filters

from LDMX.Detectors.makePath import *
from LDMX.SimCore import simcfg

#
# Instantiate the simulator.
#
sim = simulator.simulator("mySim")

#
# Set the path to the detector to use (pulled from job config)
#
detector='ldmx-det-vDET'
sim.setDetector( detector, False ) #no scoring planes needed 

#
# Set run parameters. These are all pulled from the job config 
#
p.run = RUNNUMBER
nElectrons = nEle
beamEnergy=beamE;  #in GeV                                                                                                                               

p.maxEvents = 10000

sim.description = "Inclusive "+str(beamEnergy)+" GeV electron events, "+str(nElectrons)+"e"
sim.beamSpotSmear = [20., 80., 0]


from LDMX.SimCore import generators as gen
sim.generators.append( gen.single_8gev_e_upstream_tagger() )

#Ecal and Hcal hardwired/geometry stuff
import LDMX.Ecal.ecal_hardcoded_conditions
from LDMX.Ecal import EcalGeometry
#Hcal hardwired/geometry stuff
from LDMX.Hcal import HcalGeometry
import LDMX.Hcal.hcal_hardcoded_conditions

#sim is the only sequence we need 
p.sequence=[ sim ]

p.keep=["drop .*SimParticles.*"]
p.outputFiles=["simoutput.root"]

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.

#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


     
