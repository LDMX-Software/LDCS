#!/usr/bin/python

import sys
import os
import argparse
import json


# We need the ldmx configuration package to construct the processor objects
from LDMX.Framework import ldmxcfg


p = ldmxcfg.Process('signal')
p.maxTriesPerEvent = 100
p.maxEvents = NUMEVENTS
p.logFrequency = int(p.maxEvents/20)
p.termLogLevel = 1

lheLib=INPUTFILE
# Dark Brem Vertex Library
# 1) Unpack the archive
import tarfile
with tarfile.open(lheLib,"r:gz") as ar :
    ar.extractall()

# 2) Define path to library
#   extracting the library puts the directory in the current working directory
#   so we just need the basename
db_event_lib_path = os.path.basename( lheLib ).replace('.tar.gz','')


# Get A' mass from the dark brem library name
lib_parameters = os.path.basename(db_event_lib_path).split('_')
ap_mass = float(lib_parameters[lib_parameters.index('mA')+1])*1000.
run_num = int(lib_parameters[lib_parameters.index('run')+1])

#out_file_name = '%s_mAMeV_%04d_epsilon_%s_minApE_%d_minPrimEatEcal_%d_Nevents_%d_run_%04d.root'%(
#            style_name,int(ap_mass),arg.epsilon,int(arg.minApE),int(arg.minPrimaryE),p.maxEvents,run_num)

p.outputFiles = [ "simoutput.root" ] #os.path.join( full_out_dir , out_file_name ) ]

p.run = int('%04d%04d'%(int(ap_mass),run_num)) #RUNNUMBER #

# set up simulation
#sim = None #declare simulator object
from LDMX.Biasing import target
sim = target.dark_brem( ap_mass , db_event_lib_path , 'ldmx-det-v12' )

# attach processors to the sequence pipeline
from LDMX.Ecal import ecal_hardcoded_conditions, EcalGeometry
from LDMX.Ecal import digi as eDigi
from LDMX.Ecal import vetos
from LDMX.Hcal import digi as hDigi
from LDMX.Hcal import HcalGeometry
from LDMX.TrigScint import trigScint 
from LDMX.TrigScint.trigScint import trigScintTrack 

p.sequence = [
        sim ,
        eDigi.EcalDigiProducer(),
        eDigi.EcalRecProducer(),
        vetos.EcalVetoProcessor(),
        hDigi.HcalDigiProducer(),
]


p.sequence.extend(
    [ trigScint.TrigScintDigiProducer.tagger(),
      trigScint.TrigScintDigiProducer.up(),
      trigScint.TrigScintDigiProducer.down(),
      trigScint.TrigScintClusterProducer.tagger(),
      trigScint.TrigScintClusterProducer.up(),
      trigScint.TrigScintClusterProducer.down(),
      trigScintTrack
  ] 
)

json.dumps(sim.description(), indent=2)
json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)

