#!/usr/bin/python

import sys
import os
import json

# Internal "process ID" for separating run numbers of different samples
pid=2

# We need the ldmx configuration package to construct the processor objects
from LDMX.Framework import ldmxcfg

p = ldmxcfg.Process( 'eat' )
p.maxEvents = 1000000
p.run = RUNNUMBER

from LDMX.Biasing import eat
# Inputs:
#   geometry, bias_factor, bias_threshold, min_nuclear_energy
bias_factor = 200.
bias_threshold = 1500. #MeV
min_nuc_energy = 2500. #MeV
bkgd_sim = eat.midshower_nuclear('ldmx-det-v12',bias_factor,bias_threshold,min_nuc_energy)
p.outputFiles = [ "simoutput.root" ]

from LDMX.Ecal import digi, vetos
from LDMX.Ecal import EcalGeometry, ecal_hardcoded_conditions
from LDMX.Hcal import hcal
p.sequence = [
        bkgd_sim,
        digi.EcalDigiProducer(),
        digi.EcalRecProducer(),
        vetos.EcalVetoProcessor(),
        hcal.HcalDigiProducer()
        ]


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


