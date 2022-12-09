#!/bin/python

import sys
import os
import json

# we need the ldmx configuration package to construct the object

from LDMX.Framework import ldmxcfg


# set a 'pass name'
passName="dqm"
p=ldmxcfg.Process(passName)
p.run = RUNNUMBER
p.inputFiles=[ INPUTNAME ]
p.histogramFile="hist_simoutput.root" 

from LDMX.DQM import dqm


if 'v12' in p.inputFiles[0] :
     trigScint_dqm = [
    dqm.TrigScintSimDQM('TrigScintSimPad2','TriggerPadTagSimHits','tag'),
    dqm.TrigScintSimDQM('TrigScintSimPad1','TriggerPadUpSimHits','up'),
    dqm.TrigScintSimDQM('TrigScintSimPad3','TriggerPadDnSimHits','down'),
    dqm.TrigScintDigiDQM('TrigScintDigiPad1','trigScintDigisPad1','pad1'),
    dqm.TrigScintDigiDQM('TrigScintDigiPad2','trigScintDigisPad2','pad2'),
    dqm.TrigScintDigiDQM('TrigScintDigiPad3','trigScintDigisPad3','pad3'),
    dqm.TrigScintClusterDQM('TrigScintClusterPad1','TriggerPad1Clusters','pad1'),
    dqm.TrigScintClusterDQM('TrigScintClusterPad2','TriggerPad2Clusters','pad2'),
    dqm.TrigScintClusterDQM('TrigScintClusterPad3','TriggerPad3Clusters','pad3'),
    dqm.TrigScintTrackDQM('TrigScintTracks','TriggerPadTracks')
    ]
else :
     trigScint_dqm= dqm.trigScint_dqm

trigger_dqm = [dqm.Trigger("Trig20","TriggerSums20Layers"), dqm.Trigger("Trig34","TriggerSums34Layers") ]
     
     
p.sequence=dqm.ecal_dqm + dqm.hcal_dqm + dqm.recoil_dqm + trigScint_dqm + trigger_dqm



#
# Set run parameters. These are all pulled from the job config 
#
p.run = 1

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.

#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


     
