#!/bin/python

import os
import sys
import json

from LDMX.Framework import ldmxcfg

thisPassName = 'sim'
p=ldmxcfg.Process(thisPassName)

#setup EOT and similar
p.maxTriesPerEvent = 1 
p.maxEvents = 1000000

#
#Set run parameters. These are all pulled from the job config so not defined here
#
p.run = RUNNUMBER
nElectrons = nEle
beamEnergy = beamE;  #in GeV      

from LDMX.SimCore import generators as gen
# from LDMX.SimCore import simulator
from LDMX.SimCore import bias_operators
from LDMX.SimCore import kaon_physics
from LDMX.SimCore import photonuclear_models as pn
from LDMX.Biasing import ecal
from LDMX.Biasing import filters
from LDMX.Biasing import particle_filter
from LDMX.Biasing import util
from LDMX.Biasing import include as includeBiasing


# kaon_factor = 25 #Enhancement factor , default is 25 , can be set between 0 and 30
detector='ldmx-det-vDET'
if beamEnergy == 4 :
     generator=gen.single_4gev_e_upstream_tagger()
else :
     generator=gen.single_8gev_e_upstream_tagger()

mySim = ecal.photo_nuclear(detector, generator)
mySim.description = f'{beamEnergy} GeV ECal Kaon PN simulation, xsec bias 550'
# Enable and configure the biasing
# biasing factors are 450., 2500. for 4GeV , 550., 5000. for 8GeV
mySim.biasing_operators = [ bias_operators.PhotoNuclear('ecal',550.,5000.,only_children_of_primary = True) ]
# Configure the sequence in which user actions should be called.
includeBiasing.library()
mySim.actions.clear()
mySim.actions.extend([
        filters.TaggerVetoFilter(thresh=2*3800.),
        # Only consider events where a hard brem occurs
        filters.TargetBremFilter(recoil_max_p = 2*1500.,brem_min_e = 2*2500.),
        # Only consider events where a PN reaction happnes in the ECal
        filters.EcalProcessFilter(),
        # Tag all photo-nuclear tracks to persist them to the event.
        util.TrackProcessFilter.photo_nuclear()
])

# set up upKaon parameters
mySim.kaon_parameters = kaon_physics.KaonPhysics.upKaons()

# Alternative pn models
myModel = pn.BertiniAtLeastNProductsModel.kaon() 
# These are the default values of the parameters
myModel.hard_particle_threshold=0. # Count particles with >= 200 MeV as "hard"
myModel.zmin = 0 # Apply the model to any nucleus
myModel.emin = 5000. # Apply the model for photonuclear reactions with > 5000 MeV photons
myModel.pdg_ids = [130, 310, 311, 321, -321] # PDG ids for K^0_L, K^0_S, K^0, K^+, and K^- respectively
myModel.min_products = 1 # Require at least 1 hard particle from the list above

# Change the default model to the kaon producing model
mySim.photonuclear_model = myModel

# Add the filter at the end of the current list of user actions. 
# Filter for events with a kaon daughter
myFilter = particle_filter.PhotoNuclearProductsFilter.kaon()
mySim.actions.extend([myFilter])


##################################################################
# Below should be the same for all sim scenarios

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
from LDMX.Recon.simpleTrigger import simpleTrigger


#and reco...

#TS digi + clustering + track chain. downstream pad moved to far upstream, but only in v14; left where it was in v12
tsDigisDown  =TrigScintDigiProducer.pad1()
tsDigisTag   =TrigScintDigiProducer.pad2()
tsDigisUp    =TrigScintDigiProducer.pad3()

tsDigis = [tsDigisDown, tsDigisTag, tsDigisUp]
for digi in tsDigis : 
     digi.randomSeed = p.run
     if "v14" in detector :  #this if not used in original 3.2.0 production
          digi.number_of_strips = 48 

if "v12" in detector :
     tsDigisTag.input_collection="TriggerPadTagSimHits"
     tsDigisUp.input_collection="TriggerPadUpSimHits"
     tsDigisDown.input_collection="TriggerPadDnSimHits"

tsClustersDown  =TrigScintClusterProducer.pad1()
tsClustersTag  =TrigScintClusterProducer.pad2()
tsClustersUp  =TrigScintClusterProducer.pad3()

tsClustersDown.input_collection = tsDigisDown.output_collection
tsClustersTag.input_collection = tsDigisTag.output_collection
tsClustersUp.input_collection = tsDigisUp.output_collection

if "v12" in detector :
     tsClustersTag.pad_time = -2.
     tsClustersUp.pad_time = 0.
     tsClustersDown.pad_time = 0.

#make sure to pick up the right pass 
tsClustersTag.input_pass_name = thisPassName 
tsClustersUp.input_pass_name = tsClustersTag.input_pass_name
tsClustersDown.input_pass_name = tsClustersTag.input_pass_name

trigScintTrack.input_pass_name = thisPassName
trigScintTrack.seeding_collection = tsClustersTag.output_collection


#calorimeters. set up v12 and 13 a little differently than v14, from tom:
ecalReco   =eDigi.EcalRecProducer('ecalRecon')
if "v12" in detector or "v13" in detector :
    ecalDigi = eDigi.EcalDigiProducer(si_thickness = 0.5)
    ecalReco.v12()
else :
    ecalDigi = eDigi.EcalDigiProducer()
    ecalReco.v14()

ecalVeto   =vetos.EcalVetoProcessor('ecalVetoBDT')
hcalDigi   =hDigi.HcalDigiProducer('hcalDigi')
hcalReco   =hDigi.HcalRecProducer('hcalRecon')
hcalVeto   =hcal.HcalVetoProcessor('hcalVeto')

# electron counter for trigger processor 
eCount = ElectronCounter( nElectrons, "ElectronCounter") # first argument is number of electrons in simulation
eCount.use_simulated_electron_number = True 


#trigger setup, just to have the 'default' decision, no skim on it 
simpleTrigger.start_layer= 0   #make sure it doesn't start from 1 (old default bug)
simpleTrigger.input_pass=thisPassName
simpleTrigger.beamEnergy = 8000.   # has to be a float, int will break
simpleTrigger.thresholds = [3000., 2000. + beamEnergy]  # 8 GeV trigger
simpleTrigger.trigger_collection = "DefaultTrigger3GeV"

#trigger setup for a loose skim cut, since we don't know what the final cut will be yet, allowing not just 3 but 3.5 GeV total energy 
# going to much higher is pointless since biasing starts at 5 GeV photons i.e. 3 GeV electron energy 
from LDMX.Recon.simpleTrigger import TriggerProcessor

looseSkimTrigger=TriggerProcessor("looseSkimTrigger")
looseSkimTrigger.input_pass=thisPassName
looseSkimTrigger.beamEnergy = 8000.
looseSkimTrigger.thresholds = [3500., 2000. + beamEnergy]  # a looser 8 GeV trigger to skim on 
looseSkimTrigger.trigger_collection = "SkimTrigger3p5GeV"

p.skimDefaultIsDrop()
p.skimConsider("looseSkimTrigger")


#p.sequence=[ sim, ecalDigi, ecalReco, ecalVeto, tsDigisTag, tsDigisUp, tsDigisDown, tsClustersTag, tsClustersUp, tsClustersDown, trigScintTrack, eCount, simpleTrigger, hcalDigi, hcalReco, hcalVeto ]
p.sequence=[ mySim, ecalDigi, ecalReco, ecalVeto ] + tsDigis + [ tsClustersTag, tsClustersUp, tsClustersDown, trigScintTrack, eCount, simpleTrigger, looseSkimTrigger, hcalDigi, hcalReco, hcalVeto ]

p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits"]
p.outputFiles=["simoutput.root"]


p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.
#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

# rucio metadata extraction 
json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
      json.dump(p.parameterDump(),  outfile, indent=4)
