#!/bin/python

import os
import sys
import json

from LDMX.Framework import ldmxcfg

# set a 'pass name'
# the other two pass name refers to that of the input files which will be combined in this job.                                              
thisPassName="tskim"
inputPassName="sim"
nElectrons=nELE
p=ldmxcfg.Process( thisPassName )

#import all processors

# Ecal hardwired/geometry stuff
import LDMX.Ecal.EcalGeometry
import LDMX.Ecal.ecal_hardcoded_conditions
#Hcal hardwired/geometry stuff
from LDMX.Hcal import HcalGeometry
import LDMX.Hcal.hcal_hardcoded_conditions


from LDMX.Recon.electronCounter import ElectronCounter
from LDMX.Recon.simpleTrigger import simpleTrigger

#
# Set run parameters
#
p.inputFiles = [ INPUTNAME ]
p.run = RUNNUMBER

# electron counter so simpletrigger doesn't crash 
eCount = ElectronCounter( nElectrons, "ElectronCounter") # first argument is number of electrons in simulation 
eCount.use_simulated_electron_number = True #False
eCount.input_pass_name=thisPassName

#trigger skim
simpleTrigger.start_layer= 0   #make sure it doesn't start from 1 (old default bug)
simpleTrigger.input_pass=inputPassName
p.skimDefaultIsDrop()
p.skimConsider("simpleTrigger")

p.sequence=[ eCount, simpleTrigger ] 

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


     
