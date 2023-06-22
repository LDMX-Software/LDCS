#!/bin/python

import os
import sys
import json

from LDMX.Framework import ldmxcfg

# set a 'pass name'; avoid sim or reco(n) as they are apparently overused
p=ldmxcfg.Process("BDTskim")

#import all processors

# Ecal hardwired/geometry stuff
import LDMX.Ecal.EcalGeometry
import LDMX.Ecal.ecal_hardcoded_conditions
import LDMX.Hcal.HcalGeometry
import LDMX.Hcal.hcal_hardcoded_conditions

from LDMX.Ecal import vetos
ecalVeto   =vetos.EcalVetoProcessor('ecalVetoBDTForSkim')
                                                                                                                                                         
p.run = RUNNUMBER
p.inputFiles = [ INPUTNAME ]
p.outputFiles=[ "simoutput.root" ] 
#
# Configure the sequence in which user actions should be called.
#

p.sequence=[ ecalVeto ]

p.skimDefaultIsDrop()
p.skimConsider(ecalVeto.instanceName) #"EcalVeto_BDTskim")


p.termLogLevel = 2  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


     
