#!/bin/python    

import sys
import os
import json

# We need the ldmx configuration package to construct the processor objects        
from LDMX.Framework import ldmxcfg

nElectrons=1
passName="signal"
p=ldmxcfg.Process(passName)
p.maxTriesPerEvent = 10000
p.maxEvents = NUMEVENTS

#vDET can be v12, v14-8gev, ...
detector='ldmx-det-vDET' 

# Dark Brem Vertex Library                                                                                                                          
lheLib=INPUTFILE


lib_parameters = os.path.basename(lheLib).replace('.tar.gz','').split('_')
ap_mass = float(lib_parameters[lib_parameters.index('mA')+1])*1000.
run_num = int(lib_parameters[lib_parameters.index('run')+1])
timestamp = lib_parameters[lib_parameters.index('run')+2]
unpacked_lib = os.path.basename(lheLib).replace(f'_{timestamp}.tar.gz','')

p.run = int('%04d%04d'%(int(ap_mass),run_num)) #RUNNUMBER #             

from LDMX.Biasing import target
mySim = target.dark_brem(ap_mass, unpacked_lib, detector)

p.sequence = [ mySim ]

import os
import sys

p.outputFiles = ['simoutput.root']

import LDMX.Ecal.EcalGeometry
import LDMX.Ecal.ecal_hardcoded_conditions
import LDMX.Hcal.HcalGeometry
import LDMX.Hcal.hcal_hardcoded_conditions
import LDMX.Ecal.digi as ecal_digi
import LDMX.Ecal.vetos as ecal_vetos
import LDMX.Hcal.digi as hcal_digi

from LDMX.TrigScint.trigScint import TrigScintDigiProducer
from LDMX.TrigScint.trigScint import TrigScintClusterProducer
from LDMX.TrigScint.trigScint import trigScintTrack
ts_digis = [
        TrigScintDigiProducer.pad1(),
        TrigScintDigiProducer.pad2(),
        TrigScintDigiProducer.pad3(),
        ]
for d in ts_digis :
    d.randomSeed = 1

from LDMX.Recon.electronCounter import ElectronCounter
from LDMX.Recon.simpleTrigger import TriggerProcessor

count = ElectronCounter(1,'ElectronCounter')
count.input_pass_name = ''

layers = [20,33]
tList=[]
for iLayer in range(len(layers)) :
     tp = TriggerProcessor("TriggerSumsLayer"+str(layers[iLayer]))
     tp.start_layer= 0
     tp.end_layer= layers[iLayer]
     tp.beamEnergy=8.0
     tp.thresholds=[ 3000., 10000., 17000., 24200.]
     tp.trigger_collection= "TriggerSums"+str(layers[iLayer])+"Layers"
     tList.append(tp)


p.sequence.extend([
        ecal_digi.EcalDigiProducer(),
        ecal_digi.EcalRecProducer(), 
        ecal_vetos.EcalVetoProcessor(),
        hcal_digi.HcalDigiProducer(),
        hcal_digi.HcalRecProducer(),
        *ts_digis,
        TrigScintClusterProducer.pad1(),
        TrigScintClusterProducer.pad2(),
        TrigScintClusterProducer.pad3(),
        trigScintTrack, 
        count, 
        *tList 
        ])


p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.

#print in total this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=5
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)
