import os
import sys
import json

from LDMX.Framework import ldmxcfg
from LDMX.Biasing import target
from LDMX.SimCore import generators as gen
from LDMX.Biasing import filters
from LDMX.SimCore import bias_operators
from LDMX.Biasing import include as includeBiasing
from LDMX.Biasing import util

# We need to create a process
thisPassName = 'sim'
p = ldmxcfg.Process(thisPassName)


# We import the Ecal PN template for 8 GeV beam
detector = 'ldmx-det-v14-8gev'
sim = target.gamma_mumu(detector, gen.single_8gev_e_upstream_tagger())
sim.description = '8 GeV target muon conversion simulation'

sim.biasing_operators = [bias_operators.GammaToMuPair('target', 1.E6, 5000.)]

includeBiasing.library()
sim.actions.clear()
sim.actions.extend([
   filters.TaggerVetoFilter(thresh = 7600.),
   # Only consider events where a hard brem occurs
   filters.TargetBremFilter(recoil_max_p = 3000.,brem_min_e = 5000.),
   # Only consider events where a PN reaction happens in the ECal
   filters.TargetGammaMuMuFilter(),
   # Tag all photo-nuclear tracks to persist them to the event
   util.TrackProcessFilter.gamma_mumu()

   ])

p.run = int(sys.argv[1])
nElectrons = 1
beamEnergy = 8.0; #in GeV

p.maxEvents = 10000          #min of 10000 (from LK)
p.maxTriesPerEvent = 10000

#p.histogramFile = f'hist.root'
#p.outputFiles = [sys.argv[2]]

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

tsDigisDown = TrigScintDigiProducer.pad1()
tsDigisTag = TrigScintDigiProducer.pad2()
tsDigisUp = TrigScintDigiProducer.pad3()
tsDigisDown.randomSeed = 1
tsDigisTag.randomSeed = 1
tsDigisUp.randomSeed = 1

if "v12" in detector :
   tsDigisTag.input_collection="TriggerPadTagSimHits"
   tsDigisUp.input_collection="TriggerPadUpSimHits"
   tsDigisDown.input_collection="TriggerPadDnsSimHits"

tsClustersDown = TrigScintClusterProducer.pad1()
tsClustersTag = TrigScintClusterProducer.pad2()
tsClustersUp = TrigScintClusterProducer.pad3()

tsClustersDown.input_collection = tsDigisDown.output_collection
tsClustersTag.input_collection = tsDigisTag.output_collection
tsClustersUp.input_collection = tsDigisUp.output_collection

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

simpleTrigger = TriggerProcessor('simpleTrigger', 8000.)
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
            #simpleTrigger, 
            hcalDigi, 
            hcalReco, 
            hcalVeto]

p.keep = ["drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]
p.outputFiles=[sys.argv[2]]

p.termLogLevel = 2
logEvents = 20
if (p.maxEvents < logEvents):
   logEvents = p.maxEvents

p.logFrequency = int(p.maxEvents/logEvents)
