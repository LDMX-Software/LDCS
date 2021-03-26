#!/usr/bin/python

import sys
import os
import argparse

usage = "ldmx fire %s"%(sys.argv[0])
parser = argparse.ArgumentParser(usage,formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument("run_number",help="Set the random seed for the simulation.",type=int)

arg = parser.parse_args()

# Internal "process ID" for separating run numbers of different samples
pid=2

# We need the ldmx configuration package to construct the processor objects
from LDMX.Framework import ldmxcfg

p = ldmxcfg.Process( 'eat' )
p.maxEvents = 1000000
p.run = int('%d%05d'%(pid,arg.run_number))

from LDMX.Biasing import eat
# Inputs:
#   geometry, bias_factor, bias_threshold, min_nuclear_energy
bias_factor = 200.
bias_threshold = 1500. #MeV
min_nuc_energy = 2500. #MeV
bkgd_sim = eat.midshower_nuclear('ldmx-det-v12',bias_factor,bias_threshold,min_nuc_energy)
p.outputFiles = [ f'nuclear_Nevents_1M_MaxTries_1_BiasFactor_{bias_factor}_BiasThresh_{bias_threshold}_MinNucE_{min_nuc_energy}_run_{arg.run_number:05d}.root']

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
