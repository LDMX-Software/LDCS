#!/usr/bin/python

import sys
import os
import argparse
import json


# We need the ldmx configuration package to construct the processor objects
from LDMX.Framework import ldmxcfg


p = ldmxcfg.Process('rereco')
p.maxTriesPerEvent = 10000
p.maxEvents = 100 #NUMEVENTS
p.logFrequency = int(p.maxEvents/5)
p.termLogLevel = 1



if len(sys.argv) > 1 :
    inputName=sys.argv[1]  #specify the input name if default is not desired                                                                      
else:
    inputName="simoutput.root"



p.inputFiles = [ inputName ] #os.path.join( full_out_dir , out_file_name ) ]
p.outputFiles = [ "recoOutput.root" ] #os.path.join( full_out_dir , out_file_name ) ]


# attach processors to the sequence pipeline
from LDMX.Ecal import ecal_hardcoded_conditions, EcalGeometry
from LDMX.Ecal import digi as eDigi
from LDMX.Ecal import vetos
from LDMX.Hcal import digi as hDigi
from LDMX.Hcal import hcal_hardcoded_conditions, HcalGeometry, hcal

from LDMX.TrigScint import trigScint 
from LDMX.TrigScint.trigScint import trigScintTrack 

from LDMX.Recon.simpleTrigger import TriggerProcessor


p.sequence = [
#        eDigi.EcalDigiProducer(),
#        eDigi.EcalRecProducer(),
        vetos.EcalVetoProcessor(),
#        hDigi.HcalDigiProducer(),
     hDigi.HcalRecProducer('hcalRecon'),
     hcal.HcalVetoProcessor('hcalVeto'),
]


energies = [1300, 1500, 1700]
tList=[]
for iEnergy in range(len(energies)) :
     tp = TriggerProcessor("TriggerSumsE"+str(energies[iEnergy]))
     tp.trigger_thresholds= [energies[iEnergy]]
     tp.trigger_collection= "TriggerSumsEThr"+str(energies[iEnergy])
     tList.append(tp)
p.sequence.extend( tList )

p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits", "drop EcalDigis",  "drop EcalRecHits",  "drop .*Digis.*", "drop HcalRecHits", "drop .*SimHits.*", "drop SimParticles",  "drop TriggerPad*",  "drop Tracker*"  ] 


#json.dumps(sim.description(), indent=2)
json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)

