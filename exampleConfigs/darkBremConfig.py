"""
NOTICE

  This config is highly technical and was from a time when the dark brem simulation was in
  active development. It has multiple configuration parameters that cause the simulation to
  change methods/styles as well as the parameters of those methods and styles.

"""
#!/usr/bin/python

import sys
import os
import argparse

usage = "ldmx fire %s"%(sys.argv[0])
parser = argparse.ArgumentParser(usage,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument("-p", "--pause",dest="pause",default=False,action='store_true',
        help='Print the process and pause to continue processing.')
parser.add_argument("-v","--verbose",dest="verbose",default=False,action='store_true',
        help='Print periodic progress messages.')
parser.add_argument("-o","--outDir",dest='outDir',default='events/signal',type=str,
        help='Directory to put the output event file in.')
parser.add_argument("-m","--maxTries",dest='maxTries',default=100,type=int,
        help='Maximum number of tries before giving up on an event.')
parser.add_argument("-e","--epsilon",dest="epsilon",default=0.01,type=float,
        help="Epsilon to use in dark brem xsec calculation and biasing factor calculation.")
parser.add_argument("--minApE",dest="minApE",default=2000.,type=float,
        help="Minimum A' energy [MeV] to keep the event.")
parser.add_argument("--minPrimaryE",dest="minPrimaryE",default=3500.,type=float,
        help="Minimum primary energy [MeV] at ecal front face to keep the event.")
parser.add_argument("numEvents",type=int,
        help="Number of events to simulate.")
parser.add_argument("--batch_job",type=int,
        help="UNUSED - batch job that is being used to execute this run.")
parser.add_argument("-I", "--maxISR",dest="maxISR",default=0.,type=float, #action='store_true',
        help="Max energy loss (in [GeV}) before radiating A' (suppress ISR).")
parser.add_argument("-B", "--biasFactor",dest="bias",default=-1.,type=float,
        help="Custom bias factor (defaults to mA'^(log(mA'))/eps^2 or mA'^2/eps^2 for mA' <= 100 MeV.")


db_event_lib = parser.add_mutually_exclusive_group(required=True)
db_event_lib.add_argument("--input_file",dest="input_file",type=str,default=None,
        help="Archive a a dark brem event library to use for the model.")
db_event_lib.add_argument("--db_event_lib",dest="db_event_lib",type=str,default=None,
        help="Directory that is the dark brem event library to use for the model.")

style = parser.add_mutually_exclusive_group(required=True)
style.add_argument( "--eat", dest="eat", action='store_true',
        help='Signal inside of ECal')
style.add_argument( "--old", dest="old", action='store_true',
        help='Signal inside of Target using Old style')
style.add_argument( "--new", dest="new", action='store_true',
        help='Signal inside of Target using New style')

position = parser.add_mutually_exclusive_group(required=False)
position.add_argument("-t", "--inTarget",dest="startInTarget",default=False,action='store_true',
        help='Beam starts right at beginning of target rather than upstream of tagging tracker.')
position.add_argument("-T", "--atTSup",dest="startAtTSup",default=False,action='store_true',
        help='Beam starts right before target volume (just before TS upstream pad) rather than upstream of tagging tracker.')


arg = parser.parse_args()

# We need the ldmx configuration package to construct the processor objects
from LDMX.Framework import ldmxcfg

style_name = ''
style_id = -1
if arg.eat :
    style_name = 'eat'
    style_id = 1
elif arg.old :
    style_name = 'old'
    style_id = 2
elif arg.new :
    style_name = 'new'
    style_id = 3

p = ldmxcfg.Process('signal')
p.maxTriesPerEvent = arg.maxTries
p.maxEvents = arg.numEvents
p.logFrequency = int(arg.numEvents/20)
p.termLogLevel = 1

if arg.verbose :
    p.termLogLevel = 1
    p.logFrequency = 100

# make sure outDir is actually there
if not os.path.isdir( arg.outDir ) :
    os.makedirs( arg.outDir )

# Dark Brem Vertex Library
#  TODO add this process to the model constructor
if arg.input_file is not None:
    # 1) Unpack the archive
    import tarfile
    with tarfile.open(arg.input_file,"r:gz") as ar :
        ar.extractall()
    
    # 2) Define path to library
    #   extracting the library puts the directory in the current working directory
    #   so we just need the basename
    db_event_lib_path = os.path.basename(arg.input_file).replace('.tar.gz','')
else :
    # We were given the directory of the event library,
    #   so we don't have to do anything else
    db_event_lib_path = arg.db_event_lib
    if db_event_lib_path.endswith('/') :
        db_event_lib_path = db_event_lib_path[:-1]
#end if we need to unpack the vertex archive

# Get A' mass from the dark brem library name
lib_parameters = os.path.basename(db_event_lib_path).split('_')
ap_mass = float(lib_parameters[lib_parameters.index('mA')+1])*1000.
run_num = int(lib_parameters[lib_parameters.index('run')+1])

out_file_name = '%s_mAMeV_%04d_epsilon_%s_minApE_%d_minPrimEatEcal_%d_Nevents_%d_run_%04d.root'%(
            style_name,int(ap_mass),arg.epsilon,int(arg.minApE),int(arg.minPrimaryE),p.maxEvents,run_num)
if arg.startInTarget:
    out_file_name="inTarget_"+out_file_name
if arg.startAtTSup :
    out_file_name="atTSup_"+out_file_name
if arg.maxISR > 0 :
    out_file_name="maxISR"+str(arg.maxISR)+"_"+out_file_name
    
if p.maxEvents < 10 :
    p.logFrequency = 1
    out_file_name = 'testout_run.root'

if arg.outDir == '.' :
    full_out_dir = os.path.realpath('.')
else :
    full_out_dir = os.path.join(os.path.realpath(arg.outDir),str(int(ap_mass)))

if not os.path.exists(full_out_dir) :
    os.makedirs(full_out_dir)

p.outputFiles = [ os.path.join( full_out_dir , out_file_name ) ]
p.run = int('%d%04d%04d'%(style_id,int(ap_mass),run_num))

# set up simulation
sim = None #declare simulator object
if arg.old :
    from LDMX.SimCore import simulator
    sim = simulator.simulator( '%s_signal_sim'%style_name )
    sim.setDetector( 'ldmx-det-v12' , True )

    import glob
    possible_lhes = glob.glob( db_event_lib_path+'/*IncidentE_4.0*.lhe' )

    if len(possible_lhes) == 1 :
        the_lhe = possible_lhes[0].strip()
    else :
        raise Exception("Not exactly one LHE file simulated for 4GeV Beam and input mass")

    # count number of events in the LHE so we don't go over accidentally
    num_events = 0
    with open(the_lhe,'r') as lhef :
        for line in lhef :
            num_events += line.count('/event')
        #loop over lines
    #close lhe file

    if num_events < p.maxEvents :
        print('Resetting events to %d because that is all there is in the LHE.'%num_events)
        p.maxEvents = num_events

    from LDMX.SimCore import generators
    sim.generators = [ generators.lhe('dark_brem', the_lhe ) ] 
    sim.beamSpotSmear = [ 20., 80., 0.3504 ] #mm
elif arg.new :
    from LDMX.Biasing import target
    sim = target.dark_brem( ap_mass , db_event_lib_path , 'ldmx-det-v12' )
    if arg.startAtTSup :
        from LDMX.SimCore import generators
        sim.generators = [ generators.single_4gev_e_upstream_target() ]
        sim.position = [ 0., 0., -5. ] # mm  (1.2 mm is not enough to get us in front of TS pad
    elif arg.startInTarget :
        from LDMX.SimCore import generators
        sim.generators = [ generators.single_4gev_e_upstream_target() ]
        sim.position = [ 0., 0., -1.2 ] # mm  (1.2 mm is not enough to get us in front of TS pad
    if arg.bias > 0 :
        from LDMX.SimCore import bias_operators
        sim.biasing_operators = [
        bias_operators.DarkBrem.target( arg.bias )
        ]

        #        sim.direction = [ 0., 0., 1. ] # momentum vector
    if arg.maxISR > 0 :
        from LDMX.SimCore import dark_brem
        db_model = dark_brem.VertexLibraryModel( db_event_lib_path  )
        db_model.threshold = 4. - arg.maxISR # GeV - minimum energy electron needs to have to dark brem         
        #        target.dark_brem.threshold = 4. - arg.maxISR # GeV: make sure electron has all energy left
        #        target.dark_brem.VertexLibraryModel.threshold = 4. - arg.maxISR # GeV: make sure electron has all energy left
        #        sim.threshold = 4. - arg.maxISR # GeV: make sure electron has all energy left
        sim.dark_brem.activate( ap_mass , db_model )
    print( sim.description )
else :
    from LDMX.Biasing import eat
    sim = eat.dark_brem( ap_mass , db_event_lib_path , 'ldmx-det-v12' )
# signal style

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

if not (arg.startInTarget or arg.startAtTSup or arg.old) :
    p.sequence.extend(
    [ trigScint.TrigScintDigiProducer.tagger(),
    trigScint.TrigScintDigiProducer.up(),
    trigScint.TrigScintDigiProducer.down(),
    trigScint.TrigScintClusterProducer.tagger(),
    trigScint.TrigScintClusterProducer.up(),
    trigScint.TrigScintClusterProducer.down(),
    trigScintTrack
#    trigScint.TrigScintTrackProducer.trigScintTrack
    ] )

if arg.pause :
    p.pause()
