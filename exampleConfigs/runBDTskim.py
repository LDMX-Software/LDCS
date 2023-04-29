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

from LDMX.Ecal import vetos
ecalVeto   =vetos.EcalVetoProcessor('ecalVetoBDT')


#add these to do something apart from just skimming                                                                                                   
from LDMX.TrigScint.trigScint import TrigScintClusterProducer
from LDMX.TrigScint.trigScint import trigScintTrack

trigScintTrack.delta_max = 0.75


#pull in input file
fileList= sys.argv[1]
outputNameString= "batch-"+str(sys.argv[2]) #+str(sys.argv[2])+"-"+str(sys.argv[3])

#experiment with using a file list 
with open(fileList) as inputFiles :
#     lines= inputFiles.readlines()
     p.inputFiles = [ line.strip('\n') for line in inputFiles.readlines() ]
#     for line in lines :
#          p.inputFiles.append(line.strip('\n') )
     
print( p.inputFiles )
#
# Configure the sequence in which user actions should be called.
#

p.sequence=[ ecalVeto ] #TrigScintClusterProducer.tagger(), TrigScintClusterProducer.up(), TrigScintClusterProducer.down(), trigScintTrack ]# ecalVeto ]

p.skimDefaultIsDrop()
p.skimConsider(ecalVeto.instanceName) #"EcalVeto_BDTskim")

outname="BDTskim_tskimmed_1e_ecal_PN_v2.3.0_"+outputNameString+".root"
p.outputFiles=[ outname ]


p.termLogLevel = 2  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


     
