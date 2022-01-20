import sys
from LDMX.Framework import ldmxcfg
from LDMX.EventProc.ecalDigis import ecalDigis
from LDMX.EventProc.simpleTrigger import simpleTrigger
from LDMX.EventProc.hcalDigis import hcalDigis
from LDMX.EventProc.trackerHitKiller import trackerHitKiller
p=ldmxcfg.Process("recon")
p.libraries.append("libEventProc.so")
hcalVeto = ldmxcfg.Producer("hcalVeto", "ldmx::HcalVetoProcessor")
hcalVeto.parameters["pe_threshold"] = 5.0
hcalVeto.parameters["collection_name"] = "HcalVeto"
hcalVeto.parameters["max_time"] = 50.
hcalVeto.parameters["max_depth"] = 4000.0
hcalVeto.parameters["back_min_pe"] = 1.0
simpleTrigger.parameters["threshold"] = 3160.0
simpleTrigger.parameters["end_layer"] = 20
findable_track = ldmxcfg.Producer("findable", "ldmx::FindableTrackProcessor")
p.sequence=[ecalDigis, simpleTrigger, trackerHitKiller, findable_track, hcalDigis, hcalVeto ]
p.keep.append("drop MagnetScoringPlaneHits")
p.keep.append("drop HcalScoringPlaneHits")
p.skimDefaultIsDrop()
p.skimConsider("simpleTrigger")
p.inputFiles = [ INPUTFILE ]
p.outputFiles = [ "simoutput.root" ]
p.printMe()

