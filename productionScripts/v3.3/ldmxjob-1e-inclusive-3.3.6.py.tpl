#!/bin/python

import sys
import os
import json

# we need the ldmx configuration package to construct the object

from LDMX.Framework import ldmxcfg

# set a 'pass name'
passName="sim"
p=ldmxcfg.Process(passName)

#import all processors
from LDMX.SimCore import generators
from LDMX.SimCore import simulator
from LDMX.Biasing import filters

from LDMX.Detectors.makePath import *
from LDMX.SimCore import simcfg

#
# Instantiate the simulator.
#
sim = simulator.simulator("mySim")

#
# Set the path to the detector to use (pulled from job config)
#
detector='ldmx-det-vDET'
sim.setDetector( detector, True )
sim.scoringPlanes = makeScoringPlanesPath(detector)

#
# Set run parameters. These are all pulled from the job config 
#
p.run = RUNNUMBER
nElectrons = nEle
beamEnergy=beamE;  #in GeV                                                                                                                               

p.maxEvents = 10000

sim.description = "Inclusive "+str(beamEnergy)+" GeV electron events, "+str(nElectrons)+"e"
sim.beamSpotSmear = [20., 80., 0]


from LDMX.SimCore import generators as gen
sim.generators.append( gen.single_8gev_e_upstream_tagger() )

#Ecal and Hcal hardwired/geometry stuff
import LDMX.Ecal.ecal_hardcoded_conditions
from LDMX.Ecal import EcalGeometry
#Hcal hardwired/geometry stuff
from LDMX.Hcal import HcalGeometry
import LDMX.Hcal.hcal_hardcoded_conditions


from LDMX.Ecal import digi as eDigi
from LDMX.Ecal import vetos
from LDMX.Hcal import digi as hDigi
from LDMX.Hcal import hcal

from LDMX.Recon.simpleTrigger import TriggerProcessor

from LDMX.TrigScint.trigScint import TrigScintDigiProducer
from LDMX.TrigScint.trigScint import TrigScintQIEDigiProducer
from LDMX.TrigScint.trigScint import TrigScintRecHitProducer
from LDMX.TrigScint.trigScint import TrigScintClusterProducer
from LDMX.TrigScint.trigScint import trigScintTrack


# ecal digi chain
ecalDigi   =eDigi.EcalDigiProducer('EcalDigis')
ecalReco   =eDigi.EcalRecProducer('ecalRecon')
ecalVeto   =vetos.EcalVetoProcessor('ecalVetoBDT')

#hcal digi chain
hcalDigi   =hDigi.HcalDigiProducer('hcalDigis')
hcalReco   =hDigi.HcalRecProducer('hcalRecon')                  
hcalVeto   =hcal.HcalVetoProcessor('hcalVeto')

#TS old digi, needed mostly for reference/beamEfrac studies 
tsDigisTag  =TrigScintDigiProducer.pad2()
tsDigisUp  =TrigScintDigiProducer.pad1()
tsDigisDown  =TrigScintDigiProducer.pad3()

#TS digi + clustering + track chain
ts_digis = [
        TrigScintQIEDigiProducer.pad1(),
        TrigScintQIEDigiProducer.pad2(),
        TrigScintQIEDigiProducer.pad3(),
        ]
for d in ts_digis :
    d.randomSeed = 1

ts_rechits = [
        TrigScintRecHitProducer.pad1(),
        TrigScintRecHitProducer.pad2(),
        TrigScintRecHitProducer.pad3(),
        ]

ts_clusters = [
        TrigScintClusterProducer.pad1(),
        TrigScintClusterProducer.pad2(),
        TrigScintClusterProducer.pad3(),
        ]


from LDMX.Recon.electronCounter import ElectronCounter
eCount = ElectronCounter( nElectrons, "ElectronCounter") # first argument is number of electrons in simulation 
eCount.use_simulated_electron_number = False
eCount.input_pass_name=passName
eCount.input_collection="TriggerPadTracksY"

p.sequence=[ sim, ecalDigi, ecalReco, ecalVeto, hcalDigi, hcalReco, hcalVeto, tsDigisTag, tsDigisUp, tsDigisDown, *ts_digis, *ts_rechits, *ts_clusters, trigScintTrack, eCount ]

layers = [20,34]
tList=[]
for iLayer in range(len(layers)) :
     tp = TriggerProcessor("TriggerSumsLayer"+str(layers[iLayer]))
     tp.start_layer= 0
     tp.end_layer= layers[iLayer]
     tp.trigger_collection= "TriggerSums"+str(layers[iLayer])+"Layers"
     tList.append(tp)
p.sequence.extend( tList ) 


# ------- first attempt at tracking, taken directly from Tracking/exampleConfigs/reco.py -------

import math 

# Load the tracking module
from LDMX.Tracking import tracking

# This has to stay after defining the "TrackerReco" Process in order to load the geometry
# From the conditions
from LDMX.Tracking import geo


# Truth seeder 
# Runs truth tracking producing tracks from target scoring plane hits for Recoil
# and generated electros for Tagger.
# Truth tracks can be used for assessing tracking performance or using as seeds
truth_tracking           = tracking.TruthSeedProcessor()
truth_tracking.debug             = True
truth_tracking.trk_coll_name     = "RecoilTruthSeeds"
truth_tracking.pdgIDs            = [11]
truth_tracking.scoring_hits      = "TargetScoringPlaneHits"
truth_tracking.z_min             = 0.
truth_tracking.track_id          = -1
truth_tracking.p_cut             = 0.05 # In MeV
truth_tracking.pz_cut            = 0.03
truth_tracking.p_cutEcal         = 0. # In MeV


# These smearing quantities are default. We expect around 6um hit resolution in bending plane
# v-smearing is actually not used as 1D measurements are used for tracking. These smearing parameters
# are fed to the digitization producer.
uSmearing = 0.006       #mm
vSmearing = 0.000001    #mm

# Smearing Processor - Tagger
# Runs G4 hit smearing producing measurements in the Tagger tracker.
# Hits that belong to the same sensor with the same trackID are merged together to reduce combinatorics
digiTagger = tracking.DigitizationProcessor("DigitizationProcessor")
digiTagger.hit_collection = "TaggerSimHits"
digiTagger.out_collection = "DigiTaggerSimHits"
digiTagger.merge_hits = True
digiTagger.sigma_u = uSmearing
digiTagger.sigma_v = vSmearing

# Smearing Processor - Recoil
digiRecoil = tracking.DigitizationProcessor("DigitizationProcessorRecoil")
digiRecoil.hit_collection = "RecoilSimHits"
digiRecoil.out_collection = "DigiRecoilSimHits"
digiRecoil.merge_hits = True
digiRecoil.sigma_u = uSmearing
digiRecoil.sigma_v = vSmearing


# Seed Finder Tagger
# This runs the track seed finder looking for 5 hits in consecutive sensors and fitting them with a
# parabola+linear fit. Compatibility with expected particles is checked by looking at the track
# parameters and the impact parameters at the target or generation point. For the tagger one should look
# for compatibility with the beam orbit / beam spot

seederTagger = tracking.SeedFinderProcessor()
seederTagger.input_hits_collection =  digiTagger.out_collection
seederTagger.out_seed_collection = "TaggerRecoSeeds"
seederTagger.pmin  = 2.
seederTagger.pmax  = 8.
seederTagger.d0min = -60.
seederTagger.d0max = 0.

#Seed finder processor - Recoil
seederRecoil = tracking.SeedFinderProcessor("SeedRecoil")
seederRecoil.perigee_location = [0.,0.,0.]
seederRecoil.input_hits_collection =  digiRecoil.out_collection
seederRecoil.out_seed_collection = "RecoilRecoSeeds"
seederRecoil.bfield = 1.5
seederRecoil.pmin  = 0.1
seederRecoil.pmax  = 4.
seederRecoil.d0min = -0.5
seederRecoil.d0max = 0.5
seederRecoil.z0max = 10.


# Producer for running the CKF track finding starting from the found seeds.
tracking_tagger  = tracking.CKFProcessor("Tagger_TrackFinder")
tracking_tagger.dumpobj = False
tracking_tagger.debug = True
tracking_tagger.propagator_step_size = 1000.  #mm
tracking_tagger.bfield = -1.5  #in T #From looking at the BField map
tracking_tagger.const_b_field = False

#Target location for the CKF extrapolation
tracking_tagger.seed_coll_name = seederTagger.out_seed_collection
tracking_tagger.out_trk_collection = "TaggerTracks"

#smear the hits used for finding/fitting
tracking_tagger.trackID = -1 #1
tracking_tagger.pdgID = -9999 #11
tracking_tagger.measurement_collection = digiTagger.out_collection
tracking_tagger.min_hits = 5


#CKF Options
tracking_recoil  = tracking.CKFProcessor("Recoil_TrackFinder")
tracking_recoil.dumpobj = False
tracking_recoil.debug = True
tracking_recoil.propagator_step_size = 1000.  #mm
tracking_recoil.bfield = -1.5  #in T #From looking at the BField map
tracking_recoil.const_b_field = False

#Target location for the CKF extrapolation
#tracking_recoil.seed_coll_name = seederRecoil.out_seed_collection
tracking_recoil.seed_coll_name = "RecoilTruthSeeds"
tracking_recoil.out_trk_collection = "RecoilTracks"

#smear the hits used for finding/fitting
tracking_recoil.trackID = -1 #1
tracking_recoil.pdgID = -9999 #11
tracking_recoil.measurement_collection = digiRecoil.out_collection
tracking_recoil.min_hits = 5

# ------------ end tracking --------------------------

#add tracking processors to sequence 
p.sequence.extend([digiTagger, digiRecoil,
                truth_tracking,
                seederTagger, seederRecoil,
                tracking_tagger, tracking_recoil] )


p.keep = [ "drop MagnetScoringPlaneHits", "drop TrackerScoringPlaneHits", "drop HcalScoringPlaneHits", "drop .*SimHits.*"]
p.outputFiles=["simoutput.root"]

p.termLogLevel = 1  # default is 2 (WARNING); but then logFrequency is ignored. level 1 = INFO.

#print this many events to stdout (independent on number of events, edge case: round-off effects when not divisible. so can go up by a factor 2 or so)
logEvents=20 
if p.maxEvents < logEvents :
     logEvents = p.maxEvents
p.logFrequency = int( p.maxEvents/logEvents )

json.dumps(p.parameterDump(), indent=2)

with open('parameterDump.json', 'w') as outfile:
     json.dump(p.parameterDump(),  outfile, indent=4)


     
