import sys
from LDMX.Framework import ldmxcfg
from LDMX.EventProc.ecalDigis import ecalDigis
from LDMX.EventProc.simpleTrigger import simpleTrigger
from LDMX.EventProc.hcalDigis import hcalDigis
from LDMX.EventProc.trackerHitKiller import trackerHitKiller
p=ldmxcfg.Process("recon")
p.libraries.append("libEventProc.so")
ecalVeto = ldmxcfg.Producer("ecalVeto", "ldmx::EcalVetoProcessor")
ecalVeto.parameters["num_ecal_layers"] = 34
ecalVeto.parameters["do_bdt"] = 1
ecalVeto.parameters["bdt_file"] = "gabrielle.pkl"
ecalVeto.parameters["disc_cut"] = 0.99
ecalVeto.parameters["cellxy_file"] = "cellxy.txt"
ecalVeto.parameters["collection_name"] = "EcalVeto"
hcalVeto = ldmxcfg.Producer("hcalVeto", "ldmx::HcalVetoProcessor")
hcalVeto.parameters["pe_threshold"] = 5.0
hcalVeto.parameters["collection_name"] = "HcalVeto"
hcalVeto.parameters["max_time"] = 50.
hcalVeto.parameters["max_depth"] = 4000.0
hcalVeto.parameters["back_min_pe"] = 1.0
simpleTrigger.parameters["threshold"] = 3160.0
simpleTrigger.parameters["end_layer"] = 20
findable_track = ldmxcfg.Producer("findable", "ldmx::FindableTrackProcessor")
trackerVeto= ldmxcfg.Producer("trackerVeto", "ldmx::TrackerVetoProcessor")
p.sequence=[ecalDigis, hcalDigis, ecalVeto, hcalVeto, simpleTrigger, trackerHitKiller, findable_track, trackerVeto]
p.skimDefaultIsDrop()
p.skimConsider("simpleTrigger")
p.inputFiles = [sys.argv[1]]
p.outputFiles = [sys.argv[2]]
p.printMe()
p.histogramFile="histo.root"
