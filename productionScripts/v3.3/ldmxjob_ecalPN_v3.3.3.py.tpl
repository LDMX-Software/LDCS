#!bin/python3

import os
import sys
import json

from LDMX.Framework import ldmxcfg
from LDMX.Biasing import ecal
from LDMX.SimCore import generators as gen
from LDMX.Biasing import filters
from LDMX.SimCore import bias_operators
from LDMX.Biasing import include as includeBiasing
from LDMX.Biasing import util

# We need to create a process
thisPassName = 'sim'
p = ldmxcfg.Process(thisPassName)


#
#Set run parameters. These are all pulled from the job config
#

p.run = RUNNUMBER 
nElectrons = nELECTRONS
beamEnergy = beamE #in GeV
detector = 'ldmx-det-vDET'

p.maxEvents = 1000000     
p.maxTriesPerEvent = 1


# We import the Ecal PN template for 8 GeV beam
sim = ecal.photo_nuclear(detector, gen.single_8gev_e_upstream_tagger())
sim.description = str(beamEnergy)+' GeV ecal PN simulation'

# this should move to updates of the default setting

sim.biasing_operators = [bias_operators.PhotoNuclear('ecal', 550., 5000., only_children_of_primary = True)]
 
includeBiasing.library()
sim.actions.clear()
sim.actions.extend([
   filters.TaggerVetoFilter(thresh = 7600.),
   # Only consider events where a hard brem occurs
   filters.TargetBremFilter(recoil_max_p = 3000.,brem_min_e = 5000.),
   # Only consider events where a PN reaction happens in the ECal
   filters.EcalProcessFilter(),
   # Tag all photo-nuclear tracks to persist them to the event
   util.TrackProcessFilter.photo_nuclear()

   ])


############################################################
# Below should be the same for all sim scenarios

p.outputFiles = [ "simoutput.root" ]

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
tsDigis1 = TrigScintDigiProducer.pad1()
tsDigis2 = TrigScintDigiProducer.pad2()
tsDigis3 = TrigScintDigiProducer.pad3()
tsDigis1.randomSeed = 1
tsDigis2.randomSeed = 1
tsDigis3.randomSeed = 1

if "v12" in detector :
   tsDigis2.input_collection="TriggerPadTagSimHits"
   tsDigis3.input_collection="TriggerPadUpSimHits"
   tsDigis1.input_collection="TriggerPadDnsSimHits"

tsClusters1 = TrigScintClusterProducer.pad1()
tsClusters2 = TrigScintClusterProducer.pad2()
tsClusters3 = TrigScintClusterProducer.pad3()

tsClusters1.input_collection = tsDigis1.output_collection
tsClusters2.input_collection = tsDigis2.output_collection
tsClusters3.input_collection = tsDigis3.output_collection

#make sure to pick up the right pass
tsClusters2.input_pass_name = thisPassName
tsClusters3.input_pass_name = tsClusters2.input_pass_name
tsClusters1.input_pass_name = tsClusters2.input_pass_name

trigScintTrack.input_pass_name = thisPassName
trigScintTrack.seeding_collection = tsClusters1.output_collection
trigScintTrack.number_horizontal_bars = 24
trigScintTrack.number_vertical_bars = 0


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

#trigger setup, no skim
simpleTrigger = TriggerProcessor('simpleTrigger')
simpleTrigger.start_layer = 0
simpleTrigger.input_pass = thisPassName
simpleTrigger.beamEnergy = beamEnergy
simpleTrigger.thresholds = [beamEnergy/4.*1500.0, beamEnergy/4.*5000.0, beamEnergy/4.*8500.0, beamEnergy/4.*12100.0]


p.sequence=[sim,
            ecalDigi,
            ecalReco,
            ecalVeto,
            tsDigis1,
            tsDigis2,
            tsDigis3,
            tsClusters1,
            tsClusters2,
            tsClusters3,
            trigScintTrack,
            eCount,
            simpleTrigger, 
            hcalDigi, 
            hcalReco, 
            hcalVeto]

p.keep = ["drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]

p.termLogLevel = 2
logEvents = 20
if (p.maxEvents < logEvents):
   logEvents = p.maxEvents

p.logFrequency = int(p.maxEvents/logEvents)

#the below is needed for rucio metadata on LDCS 
json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)
