#!/bin/python

import sys
import os
import json

# We need the ldmx configuration package to construct the processor objects

from LDMX.Framework import ldmxcfg

nElectrons=1
passName="signal"
p=ldmxcfg.Process(passName)
p.maxTriesPerEvent = 100
p.maxEvents = NUMEVENTS

# Dark Brem Vertex Library
lheLib=INPUTFILE

# 2) Define path to library
#   extracting the library puts the directory in the current working directory
#   so we just need the basename
db_event_lib_path = os.path.basename( lheLib ).replace('.tar.gz','')

# Get A' mass from the dark brem library name
lib_parameters = os.path.basename(db_event_lib_path).split('_')
ap_mass = float(lib_parameters[lib_parameters.index('mA')+1])*1000.
run_num = int(lib_parameters[lib_parameters.index('run')+1])
# remove the timestamp part from the library name 
tID = lib_parameters[lib_parameters.index('run')+2]
lib_path = db_event_lib_path.replace('_'+tID,'')

p.outputFiles = ["simoutput.root"]

p.run = int('%04d%04d'%(int(ap_mass),run_num)) #RUNNUMBER #

# set up simulation
#sim = None #declare simulator object
from LDMX.Biasing import target
sim = target.dark_brem( ap_mass , lib_path , 'ldmx-det-v12' )
#
# Set the path to the detector to use. 
from LDMX.Detectors.makePath import makeScoringPlanesPath
sim.scoringPlanes = makeScoringPlanesPath('ldmx-det-v12')

# attach processors to the sequence pipeline

#Ecal and Hcal hardwired/geometry stuff
from LDMX.Ecal import ecal_hardcoded_conditions, EcalGeometry
from LDMX.Ecal import digi as eDigi
egeom = EcalGeometry.EcalGeometryProvider.getInstance()
#Hcal hardwired/geometry stuff
from LDMX.Hcal import HcalGeometry
import LDMX.Hcal.hcal_hardcoded_conditions
hgeom = HcalGeometry.HcalGeometryProvider.getInstance()

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
tsDigisTag  =TrigScintDigiProducer.tagger()
tsDigisUp  =TrigScintDigiProducer.up()
tsDigisDown  =TrigScintDigiProducer.down()

tsClustersTag  =TrigScintClusterProducer.tagger()
tsClustersUp  =TrigScintClusterProducer.up()
tsClustersDown  =TrigScintClusterProducer.down()

trigScintTrack.delta_max = 0.75 

from LDMX.Recon.electronCounter import ElectronCounter
eCount = ElectronCounter( nElectrons, "ElectronCounter") # first argument is number of electrons in simulation 
eCount.use_simulated_electron_number = True #False
eCount.input_pass_name=passName


p.sequence=[ sim, ecalDigi, ecalReco, ecalVeto, hcalDigi, hcalReco, hcalVeto, tsDigisTag, tsDigisUp, tsDigisDown, tsClustersTag, tsClustersUp, tsClustersDown, trigScintTrack, eCount ]

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

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.

#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)

