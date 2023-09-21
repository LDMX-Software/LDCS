#!/bin/python

import os
import sys
import json

from LDMX.Framework import ldmxcfg

# set a 'pass name';
thisPassName="sim"
p=ldmxcfg.Process(thisPassName)

p.maxTriesPerEvent = 1   #10000
#import all processors

from LDMX.Biasing import target
from LDMX.SimCore import generators as gen

#
#Set run parameters. These are all pulled from the job config
#

p.run = RUNNUMBER
nElectrons = nEle
beamEnergy=beamE;  #in GeV     
detector='ldmx-det-vDET'

# now use them 
sim = target.photo_nuclear(detector, gen.single_4gev_e_upstream_tagger())
sim.beamSpotSmear = [20.,80.,0.]
sim.description = '4 GeV target PN simulation'


############################################################
# Below should be the same for all sim scenarios

p.maxEvents = 1000000

p.outputFiles=[ "simoutput.root" ] 


import LDMX.Ecal.EcalGeometry
import LDMX.Ecal.ecal_hardcoded_conditions
import LDMX.Hcal.HcalGeometry
import LDMX.Hcal.hcal_hardcoded_conditions

from LDMX.Ecal import digi as eDigi
from LDMX.Ecal import vetos
from LDMX.Hcal import digi as hDigi
from LDMX.Hcal import hcal

from LDMX.TrigScint.trigScint import TrigScintDigiProducer
from LDMX.TrigScint.trigScint import TrigScintClusterProducer
from LDMX.TrigScint.trigScint import trigScintTrack

from LDMX.Recon.electronCounter import ElectronCounter
from LDMX.Recon.simpleTrigger import TriggerProcessor


#and reco...

#TS digi + clustering + track chain. downstream pad removed to far upstream, but only in v14; left where it was in v12
tsDigisDown = TrigScintDigiProducer.pad1()
tsDigisTag = TrigScintDigiProducer.pad2()
tsDigisUp = TrigScintDigiProducer.pad3()
tsDigisDown.randomSeed = 1
tsDigisTag.randomSeed = 1
tsDigisUp.randomSeed = 1

if "v12" in detector :
   tsDigisTag.input_collection="TriggerPadTagSimHits"
   tsDigisUp.input_collection="TriggerPadUpSimHits"
   tsDigisDown.input_collection="TriggerPadDnSimHits"

tsClustersDown = TrigScintClusterProducer.pad1()
tsClustersTag = TrigScintClusterProducer.pad2()
tsClustersUp = TrigScintClusterProducer.pad3()

tsClustersDown.input_collection = tsDigisDown.output_collection
tsClustersTag.input_collection = tsDigisTag.output_collection
tsClustersUp.input_collection = tsDigisUp.output_collection

#make sure to pick up the right pass
tsClustersTag.input_pass_name = thisPassName
tsClustersUp.input_pass_name = tsClustersTag.input_pass_name
tsClustersDown.input_pass_name = tsClustersTag.input_pass_name

trigScintTrack.input_pass_name = thisPassName
trigScintTrack.seeding_collection = tsClustersTag.output_collection


#calorimeters
ecalDigi = eDigi.EcalDigiProducer('ecalDigi')
ecalReco = eDigi.EcalRecProducer('ecalRecon')
ecalVeto = vetos.EcalVetoProcessor('ecalVetoBDT')
hcalDigi = hDigi.HcalDigiProducer('hcalDigi')
hcalReco = hDigi.HcalRecProducer('hcalRecon')
hcalVeto = hcal.HcalVetoProcessor('hcalVeto')


# electron counter so simpletrigger doesn't crash
eCount = ElectronCounter(1, "ElectronCounter") # first argument is number of electrons in simulation
eCount.use_simulated_electron_number = True
eCount.input_pass_name=thisPassName
eCount.input_collection=trigScintTrack.output_collection

#trigger setup, no skim
simpleTrigger = TriggerProcessor('simpleTrigger')
simpleTrigger.start_layer = 0
simpleTrigger.input_pass = thisPassName

p.sequence=[sim, 
            ecalDigi, 
            ecalReco, 
            ecalVeto, 
            tsDigisTag, 
            tsDigisUp, 
            tsDigisDown, 
            tsClustersTag, 
            tsClustersUp, 
            tsClustersDown, 
            trigScintTrack, 
            eCount, 
            simpleTrigger, 
            hcalDigi, 
            hcalReco, 
            hcalVeto]

p.keep = ["drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]


p.termLogLevel = 2
logEvents=20
if p.maxEvents < logEvents :
   logEvents = p.maxEvents
p.logFrequency = int(p.maxEvents/logEvents)

#for rucio metadata: dump all parameter settings  
json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)
