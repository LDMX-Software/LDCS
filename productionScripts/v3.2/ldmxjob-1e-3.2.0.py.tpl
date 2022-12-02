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
sim.setDetector( 'ldmx-det-vDET', True )
sim.scoringPlanes = makeScoringPlanesPath('ldmx-det-vDET')

#
# Set run parameters. These are all pulled from the job config 
#
p.run = RUNNUMBER
nElectrons = nEle
beamEnergy=beamE;  #in GeV                                                                                                                                              

sim.description = "Inclusive "+str(beamEnergy)+" GeV electron events, "+str(nElectrons)+"e"
#sim.randomSeeds = [ SEED1 , SEED2 ]
sim.beamSpotSmear = [20., 80., 0]


mpgGen = generators.multi( "mgpGen" ) # this is the line that actually creates the generator                                                                            
mpgGen.vertex = [ -27.926, 0., -700 ] # mm                                                                                                                              
mpgGen.nParticles = nElectrons
mpgGen.pdgID = 11
mpgGen.enablePoisson = False #True                                                                                                                                      

import math
theta = math.radians(4.5)
beamEnergyMeV=1000*beamEnergy
px = beamEnergyMeV*math.sin(theta)
py = 0.;
pz= beamEnergyMeV*math.cos(theta)
mpgGen.momentum = [ px, py, pz ]

#
# Set the multiparticle gun as generator
#
sim.generators = [ mpgGen ]


#reconstruction and vetoes 

#Ecal and Hcal hardwired/geometry stuff
#import LDMX.Ecal.EcalGeometry
import LDMX.Ecal.ecal_hardcoded_conditions
from LDMX.Ecal import EcalGeometry
#egeom = EcalGeometry.EcalGeometryProvider.getInstance()
#Hcal hardwired/geometry stuff
from LDMX.Hcal import HcalGeometry
import LDMX.Hcal.hcal_hardcoded_conditions
#hgeom = HcalGeometry.HcalGeometryProvider.getInstance()


from LDMX.Ecal import digi as eDigi
from LDMX.Ecal import vetos
from LDMX.Hcal import digi as hDigi
from LDMX.Hcal import hcal

from LDMX.Recon.simpleTrigger import TriggerProcessor

from LDMX.TrigScint.trigScint import TrigScintDigiProducer
from LDMX.TrigScint.trigScint import TrigScintClusterProducer
from LDMX.TrigScint.trigScint import trigScintTrack


# ecal digi chain
ecalDigi   =eDigi.EcalDigiProducer('EcalDigis')
ecalReco   =eDigi.EcalRecProducer('ecalRecon')
ecalVeto   =vetos.EcalVetoProcessor('ecalVetoBDT')

#hcal digi chain
hcalDigi   =hDigi.HcalDigiProducer('hcalDigis')
hcalReco   =hDigi.HcalRecProducer('hcalRecon')                  
hcalVeto   =hcal.HcalVetoProcessor('hcalVeto')
#hcalDigi.inputCollName="HcalSimHits"
#hcalDigi.inputPassName=passName

#TS digi + clustering + track chain
tsDigisTag  =TrigScintDigiProducer.pad2()
tsDigisUp  =TrigScintDigiProducer.pad1()
tsDigisDown  =TrigScintDigiProducer.pad3()

tsClustersTag  =TrigScintClusterProducer.pad2()
tsClustersUp  =TrigScintClusterProducer.pad1()
tsClustersDown  =TrigScintClusterProducer.pad3()
tsDigisUp.verbosity=3
tsClustersUp.verbosity=3
trigScintTrack.verbosity=3

trigScintTrack.delta_max = 0.75 

from LDMX.Recon.electronCounter import ElectronCounter
eCount = ElectronCounter( nElectrons, "ElectronCounter") # first argument is number of electrons in simulation 
eCount.use_simulated_electron_number = False
eCount.input_pass_name=passName

p.sequence=[ sim, ecalDigi, ecalReco, ecalVeto, hcalDigi, hcalReco, hcalVeto, tsDigisTag, tsDigisUp, tsDigisDown, tsClustersTag, tsClustersUp, tsClustersDown, trigScintTrack, eCount ]
#hcal digi keeps crashing in config step
#p.sequence=[ sim, ecalDigi, ecalReco, ecalVeto, tsDigisTag, tsDigisUp, tsDigisDown, tsClustersTag, tsClustersUp, tsClustersDown, trigScintTrack, eCount ]

layers = [20,34]
tList=[]
for iLayer in range(len(layers)) :
     tp = TriggerProcessor("TriggerSumsLayer"+str(layers[iLayer]))
     tp.start_layer= 0
     tp.end_layer= layers[iLayer]
     tp.trigger_collection= "TriggerSums"+str(layers[iLayer])+"Layers"
     tList.append(tp)
p.sequence.extend( tList ) 

p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]
p.outputFiles=["simoutput.root"]

p.maxEvents = 100

p.termLogLevel = 0  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.

#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


     
