#!/bin/python3

import os
import sys
import json

from LDMX.Framework import ldmxcfg

# set a 'pass name'; avoid sim or reco(n) as they are apparently overused
p=ldmxcfg.Process("v12")

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
# Set the path to the detector to use. 
#
sim.setDetector( 'ldmx-det-v12', True  )
sim.scoringPlanes = makeScoringPlanesPath('ldmx-det-v12')

#
# Set run parameters
#
p.run = RUNNUMBER

nElectrons = 4
sim.description = "Inclusive 4 GeV electron events, "+str(nElectrons)+"e"
sim.randomSeeds = [ SEED1 , SEED2 ]
sim.beamSpotSmear = [20., 80., 0]


mpgGen = generators.multi( "mgpGen" ) # this is the line that actually creates the generator                                                                            
mpgGen.vertex = [ -27.926, 0., -700 ] # mm                                                                                                                              
mpgGen.nParticles = nElectrons
mpgGen.pdgID = 11
mpgGen.enablePoisson = False #True                                                                                                                                      

import math
theta = math.radians(4.5)
beamEnergy=4000;  #in MeV                                                                                                                                               
px = beamEnergy*math.sin(theta)
py = 0.;
pz= beamEnergy*math.cos(theta)
mpgGen.momentum = [ px, py, pz ]

#
# Set the multiparticle gun as generator
#
sim.generators = [ mpgGen ]


p.sequence=[ sim ]

p.outputFiles=["simoutput.root"]

p.maxEvents = 100

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )


with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


     
