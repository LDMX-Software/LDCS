#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import argparse
import sys
import os
import json
import hashlib
import zlib
import time

# logging
logger = logging.getLogger('LDMX.SimProd.Helper')
logger.setLevel(logging.INFO)
log_handler_stderr = logging.StreamHandler()
log_handler_stderr.setFormatter(
    logging.Formatter('[%(asctime)s] [%(name)s] [%(levelname)s] [%(process)d] [%(message)s]'))
logger.addHandler(log_handler_stderr)

# read ldmx.config to dict
def parse_ldmx_config(config='ldmxjob.config'):
    conf_dict = {}
    with open(config, 'r') as conf_f:
        for line in conf_f:
            kv = line.split('=', 2)
            if len(kv) != 2:
                logger.error('Malformed %s line: %s', config, line)
                continue
            conf_dict[kv[0]] = kv[1].strip()
    # split physics process from config
    if not 'PhysicsProcess' in conf_dict: 
        logger.error('PhysicsProcess is not defined in the %s. Job aborted.', config)
        sys.exit(1)
    # ensure both random seeds are set
#    if 'RandomSeed1' not in conf_dict or 'RandomSeed2' not in conf_dict:
#        logger.error('RandomSeed1 and/or RandomSeed2 is not set in %s. Job aborted.', config)
#        sys.exit(1)
    # ^^ no longer mandatory options
    for opt in ['DetectorVersion', 'FieldMap']:
        if opt not in conf_dict :
            if 'APrimeMass' in conf_dict: # don't need detector details for pure event library generation jobs 
                conf_dict[opt] = None     # just set to empty to avoid missing field later
            else :
                logger.error('%s is not defined in the %s. Job aborted.', opt, config)
                sys.exit(1)
    # ensure FileName is set to something
    if 'FileName' not in conf_dict:
        conf_dict['FileName'] = 'output.sif'
            # ensure FileName is set to something
    if 'LdmxImage' not in conf_dict:
        conf_dict['FileName'] = 'output.sif'
    #batch id will be used for storage directory structure. Should ALWAYS be set.
    if 'BatchID' not in conf_dict:
        logger.error('BatchID is not defined in the %s. Needed for storage directory structure. Job aborted.', config)
        sys.exit(1)

    return conf_dict

# read ldmx.config to dict
def parse_ldmx_imagebuild_config(config='ldmxjob.config'):
    conf_dict = {}
    with open(config, 'r') as conf_f:
        for line in conf_f:
            #allow sw versions to be a comma separated list of key=val pairs
            for pair in line.split(',') if "," in line else line :
                for kv in pair.split('=', 2) :
                    if len(kv) != 2:
                        logger.error('Malformed %s line: %s', config, line)
                        continue
                    conf_dict[kv[0]] = kv[1].strip()
    #some stuff is mandatory 
    if not 'FileName' in conf_dict:
        logger.error('Output image name ("FileName") is not defined in the %s. Job aborted.', config)
        sys.exit(1)
    if not 'DockerRepo' in conf_dict:
        logger.error('DockerHub repository ("DockerRepo") is not defined in the %s. Job aborted.', config)
        sys.exit(1)
    if not 'DockerTag' in conf_dict:
        logger.error('DockerHub container tag ("DockerTag") is not defined in the %s. Job aborted.', config)
        sys.exit(1)
        
    #we made it this far. admit that we're building an image
    conf_dict['IsImage']=='True'

    return conf_dict

def print_eval(conf_dict, makeSingImage=False):
    if makeSingImage :
        printString= ('export DOCKER_REPO="{DockerRepo}"\n'
                      'export DOCKER_REPO="{DockerTag}"\n'
                      'export OUTPUTDATAFILE="{FileName}"'.format(**conf_dict))
    else :
        printString= ('export DETECTOR="ldmx-det-full-v{DetectorVersion}-fieldmap-magnet"\n'
                  'export FIELDMAP="{FieldMap}"\n'
                  'export OUTPUTDATAFILE="{FileName}"'.format(**conf_dict))
        if 'APrimeMass' in conf_dict :
            printString+=('\nexport APMASS="{APrimeMass}"\n'
                          'export NEVENTS="{NumberOfEvents}"\n'
                          'export RUNNB="{runNumber}"\n'
                          'export ENERGIES="{IncidentEnergies}"'
                          .format(**conf_dict))

    print( printString )


def calculate_md5_adler32_checksum(file, chunk_size=524288):
    md5 = hashlib.md5()
    adler32 = 1
    with open(file, 'rb') as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            md5.update(chunk)
            adler32 = zlib.adler32(chunk, adler32) & 0xffffffff
    return (md5.hexdigest(), '{:08x}'.format(adler32))

def collect_from_json( infile, in_conf ):
    #function to convert json nested list to flat metadata list 
    config_dict = {}

    #get a minimum of info from production config to return in the case the parameter dump wasn't created (like v1.7 running)
    isRecon = False 
    isTriggerSkim = False 
    isBDTSkim = False 
    if in_conf.get("IsTriggerSkim") :
        if in_conf.get("IsTriggerSkim") == "Yes" :
            isTriggerSkim=True
    if in_conf.get("IsBDTSkim") :
        if in_conf.get("IsBDTSkim") == "Yes" :
            isBDTSkim=True
    if in_conf.get("IsRecon") :
        if in_conf.get("IsRecon") == "Yes" :
            isRecon=True
    if in_conf.get("InputFilesPerJob") :
        config_dict["NumberInputFiles"] = in_conf.get("InputFilesPerJob")
    config_dict['IsRecon'] = isRecon
    config_dict['IsTriggerSkim'] = isTriggerSkim
    config_dict['IsBDTSkim'] = isBDTSkim

    try:
        with open(infile, "r") as jf :
            mjson = json.load(jf)
    except Exception as e:
        logger.error('Failed to open {}: {}'.format(infile, str(e)))
        return config_dict 
#        sys.exit(1)

    logger.info('Opened {}'.format(infile))
    logger.info(json.dumps(mjson, indent = 2, sort_keys=True ))

    if 'generators' in mjson['sequence'][0] :
        config_dict['GunPositionX[mm]']  = mjson['sequence'][0]['generators'][0]['position'][0] if 'position' in mjson['sequence'][0]['generators'][0] else None
        config_dict['GunPositionY[mm]']  = mjson['sequence'][0]['generators'][0]['position'][1] if 'position' in mjson['sequence'][0]['generators'][0] else None
        config_dict['GunPositionZ[mm]']  = mjson['sequence'][0]['generators'][0]['position'][2] if 'position' in mjson['sequence'][0]['generators'][0] else None
        config_dict['MomentumVectorX[GeV]'] = mjson['sequence'][0]['generators'][0]['direction'][0] if 'direction' in mjson['sequence'][0]['generators'][0] else None
        config_dict['MomentumVectorY[GeV]'] = mjson['sequence'][0]['generators'][0]['direction'][1] if 'direction' in mjson['sequence'][0]['generators'][0] else None
        config_dict['MomentumVectorZ[GeV]'] = mjson['sequence'][0]['generators'][0]['direction'][2] if 'direction' in mjson['sequence'][0]['generators'][0] else None
        config_dict['BeamEnergy']    = mjson['sequence'][0]['generators'][0]['energy']  if 'energy' in mjson['sequence'][0]['generators'][0] else None
        config_dict['BeamParticle']  = mjson['sequence'][0]['generators'][0]['particle'] if 'particle' in mjson['sequence'][0]['generators'][0] else None
        #or, if we're using the multiparticle gun, which has different names and conventions for the same parameters
        if not config_dict['GunPositionX[mm]'] :
            config_dict['GunPositionX[mm]']  = mjson['sequence'][0]['generators'][0]['vertex'][0] if 'vertex' in mjson['sequence'][0]['generators'][0] else None
            config_dict['GunPositionY[mm]']  = mjson['sequence'][0]['generators'][0]['vertex'][1] if 'vertex' in mjson['sequence'][0]['generators'][0] else None
            config_dict['GunPositionZ[mm]']  = mjson['sequence'][0]['generators'][0]['vertex'][2] if 'vertex' in mjson['sequence'][0]['generators'][0] else None
        if not config_dict['MomentumVectorX[GeV]'] :
            config_dict['MomentumVectorX[GeV]'] = mjson['sequence'][0]['generators'][0]['momentum'][0] if 'momentum' in mjson['sequence'][0]['generators'][0] else None
            config_dict['MomentumVectorY[GeV]'] = mjson['sequence'][0]['generators'][0]['momentum'][1] if 'momentum' in mjson['sequence'][0]['generators'][0] else None
            config_dict['MomentumVectorZ[GeV]'] = mjson['sequence'][0]['generators'][0]['momentum'][2] if 'momentum' in mjson['sequence'][0]['generators'][0] else None
        if not config_dict['BeamEnergy'] :   #preferred choice is to extract the beam energy from the numbers used, rather than pull it from the batch config which doesn't explicitly set it, and could thus be wrong
            px = float( str(config_dict['MomentumVectorX[GeV]']) )
            py = float( str(config_dict['MomentumVectorY[GeV]']) )
            pz = float( str(config_dict['MomentumVectorZ[GeV]']) )   #config_dict['MomentumVectorZ'])
            import math
            energy = int( math.sqrt( px*px + py*py + pz*pz ) + 0.5 )
            # now use this to normalise the momentum vector
            config_dict['MomentumVectorX[GeV]'] = px/energy
            config_dict['MomentumVectorY[GeV]'] = py/energy
            config_dict['MomentumVectorZ[GeV]'] = pz/energy
            #and then set the beam energy. first get the units right
            while energy > 999 :
                energy = energy/1000.
                
            config_dict['BeamEnergy'] = energy
        if not config_dict['BeamParticle'] :
            config_dict['BeamParticle']  = mjson['sequence'][0]['generators'][0]['pdgID'] if 'pdgID' in mjson['sequence'][0]['generators'][0] else None
        #note: defaults to 1, rather than "None"
        config_dict['nBeamParticles']  = mjson['sequence'][0]['generators'][0]['nParticles'] if 'nParticles' in mjson['sequence'][0]['generators'][0] else 1
            
        
    if 'beamSpotSmear' in mjson['sequence'][0] :
        config_dict['BeamSpotSizeX[mm]'] = mjson['sequence'][0]['beamSpotSmear'][0]
        config_dict['BeamSpotSizeY[mm]'] = mjson['sequence'][0]['beamSpotSmear'][1]
        config_dict['BeamSpotSizeZ[mm]'] = mjson['sequence'][0]['beamSpotSmear'][2]

    if 'runNumber' in mjson['sequence'][0] :
        config_dict['RunNumber'] = mjson['sequence'][0]['runNumber']
    elif 'run' in mjson :
        config_dict['RunNumber'] = mjson['run']
    else :
        logger.error('RunNumber is not set in %s. Job aborted.', infile)
        sys.exit(1)

    if 'randomSeeds' in mjson['sequence'][0] :
        config_dict['RandomSeed1'] = mjson['sequence'][0]['randomSeeds'][0]
        config_dict['RandomSeed2'] = mjson['sequence'][0]['randomSeeds'][1]
#    else :   
# should probably first look up if we're using an input file, or if we can find a master random seed, and only in those cases accept not having a random seed specified.     
#        logger.error('RandomSeed1 and/or RandomSeed2 is not set in %s. Job aborted.', infile)
#        sys.exit(1)

    if 'actions' in mjson['sequence'][0] :
        for params in mjson['sequence'][0]['actions'] :
            p = params['class_name']
            key=p.split("::")[-1]  #these can be long :: separated name spaces and class names; get the last 
            for k, val in params.items() :
                if 'threshold' in k :
                    keepKey=key+"_"+k+'[MeV]'
                    config_dict[keepKey]=val

    #don't attempt setting these if we're actually using a sim input file)
    if not 'inputFiles' in mjson or mjson['inputFiles'] == [] : #in_conf.get("InputFile") : <-- adjust this; LHE files are passed as "InputFile"s but not as "p.inputFiles"
        if 'biasing_operators' in  mjson['sequence'][0] :
            for params in mjson['sequence'][0]['biasing_operators'] :
                p = params['class_name']
                key="Geant4Bias"+p.split("::")[-1]  #these can be long :: separated name spaces and class names; get the last
                for k, val in params.items() :
                    if '_name' in k :
                        continue
                    keepKey=key+"_"+k
                    if 'threshold' in k : # or 'factor' in k :
                        keepKey=keepKey+'[MeV]'
                    config_dict[keepKey]=val
        elif 'biasing_particle' in  mjson['sequence'][0] :
            config_dict['Geant4BiasParticle']  = mjson['sequence'][0]['biasing_particle'] if 'biasing_particle' in  mjson['sequence'][0] else None
            config_dict['Geant4BiasProcess']   = mjson['sequence'][0]['biasing_process'] if 'biasing_process' in  mjson['sequence'][0] else None
            config_dict['Geant4BiasVolume']    = mjson['sequence'][0]['biasing_volume'] if 'biasing_volume' in  mjson['sequence'][0] else None
            config_dict['Geant4BiasThreshold[MeV]'] = mjson['sequence'][0]['biasing_threshold'] if 'biasing_threshold' in  mjson['sequence'][0] else None
            config_dict['Geant4BiasFactor']    = mjson['sequence'][0]['biasing_factor'] if 'biasing_factor' in  mjson['sequence'][0] else None
            
        config_dict['APrimeMass']          = mjson['sequence'][0]['APrimeMass'] if 'APrimeMass' in  mjson['sequence'][0] else None
            #let these depend on if we are actually generating signal 
        if 'dark_brem' in  mjson['sequence'][0] :
            config_dict['APrimeMass[MeV]']       = mjson['sequence'][0]['dark_brem']['ap_mass'] 
            config_dict['DarkBremModel']          = mjson['sequence'][0]['dark_brem']['model']['name'] 
            if not config_dict['DarkBremModel'] == "UNDEFINED" :
                config_dict['DarkBremMethod']         = mjson['sequence'][0]['dark_brem']['model']['method'] 
                config_dict['DarkBremEpsilon']        = mjson['sequence'][0]['dark_brem']['model']['epsilon'] 
                config_dict['DarkBremThreshold[GeV]'] = mjson['sequence'][0]['dark_brem']['model']['threshold'] 
            config_dict['DarkBremOnePerEvent']    = mjson['sequence'][0]['dark_brem']['only_one_per_event'] 

        config_dict['DarkBremMethodXsecFactor'] = mjson['sequence'][0]['darkbrem_globalxsecfactor'] if config_dict['APrimeMass'] and 'darkbrem_globalxsecfactor' in  mjson['sequence'][0] else None
    
    #ok. over reco stuff, where parameter names can get confusing.
    # add here as more processors are included
    # not putting in protections here for every possible parameter name, better to let a test job fail if the parameter naming has changed

    isRecon = False #allow for checking this from parameter dump, if one exists
    for seq in mjson['sequence'] :
        procName=seq['className'].split('::')[1]  #remove namespace 
        if procName != "Simulator" :  #everything except simulation is reconstruction
            isRecon = True 
#            procName=procName.replace("ldmx::", "")
            procName=procName.replace("Producer", "")
            procName=procName.replace("Processor", "")
        if "calDigi" in procName and 'hgcroc' in seq :
            if procName == "HcalDigi" :
                config_dict[procName+'Gain'] = seq['avgGain']
                config_dict[procName+'AttLength'] = seq['attenuationLength']
            config_dict[procName+'MeV'] = seq['MeV']
            config_dict[procName+'Pedestal'] = seq['avgPedestal']
            config_dict[procName+'ReadoutThreshold'] = seq['avgReadoutThreshold']
            #now read the stuff from the actual hgcroc entry 
            config_dict[procName+'ClockCycle[ns]'] = seq['hgcroc']['clockCycle']
            config_dict[procName+'ISOI'] = seq['hgcroc']['iSOI']
            config_dict[procName+'NumberADCs'] = seq['hgcroc']['nADCs']
            #config_dict[procName+'MaxADCrange'] = seq['hgcroc']['maxADCRange']
            #config_dict[procName+'NoiseRMS'] = seq['hgcroc']['noiseRMS']
            config_dict[procName+'NoiseRMS'] = seq['avgNoiseRMS']
            config_dict[procName+'WithNoise'] = seq['hgcroc']['noise']
            config_dict[procName+'TimingJitter'] = seq['hgcroc']['timingJitter']
            #config_dict[procName+'PadCapacitance'] = seq['hgcroc']['readoutPadCapacitance']
            #config_dict[procName+'TOAThreshold'] = seq['hgcroc']['toaThreshold']
            #config_dict[procName+'TOTThreshold'] = seq['hgcroc']['totThreshold']
            #config_dict[procName+'TOTMax'] = seq['hgcroc']['totMax']
            config_dict[procName+'RateUpSlope'] = seq['hgcroc']['rateUpSlope']
            config_dict[procName+'RateDnSlope'] = seq['hgcroc']['rateDnSlope']
            config_dict[procName+'TimeUpSlope'] = seq['hgcroc']['timeUpSlope']
            config_dict[procName+'TimeDnSlope'] = seq['hgcroc']['timeDnSlope']
            config_dict[procName+'TimePeak'] = seq['hgcroc']['timePeak']
            #config_dict[procName+'DrainRate'] = seq['hgcroc']['drainRate']
        elif procName == "EcalRec" :
            config_dict[procName+'SecondOrderEnergyCorrection'] = seq['secondOrderEnergyCorrection']
            config_dict[procName+'ChargePerMIP'] = seq['charge_per_mip']
            config_dict[procName+'SiEnergyMIP'] = seq['mip_si_energy']
            config_dict[procName+'ClockCycle[ns]'] = seq['clock_cycle']
        elif procName == "EcalVeto" :
            config_dict[procName+'Layers'] = seq['num_ecal_layers']
            config_dict[procName+'DiscriminatorCut'] = seq['disc_cut']
            config_dict[procName+'BDTfile'] = seq['bdt_file']
            config_dict[procName+'DoBDT'] = seq['do_bdt']
        elif procName == "HcalVeto" :
            config_dict[procName+'MaxPE'] = seq['pe_threshold']
            config_dict[procName+'MaxTime[ns]'] = seq['max_time']
            config_dict[procName+'MaxDepth[mm]'] = seq['max_depth']
            config_dict[procName+'BackMinPE'] = seq['back_min_pe']
        elif procName == "HcalRec" :
            config_dict[procName+'PEPerMIP'] = seq['pe_per_mip']
            config_dict[procName+'VoltagePerMIP'] = seq['voltage_per_mip']
            config_dict[procName+'EnergyMIP'] = seq['mip_energy']
            config_dict[procName+'ClockCycle[ns]'] = seq['clock_cycle']
            config_dict[procName+'AvgTOAThreshold'] = seq['avgToaThreshold']             
        elif procName == "HcalDigi" :   #keep for backwards compatibility for the no-hgcroc versions (<v3.0)
            config_dict[procName+'MeanNoiseSiPM'] = seq['meanNoise']
            config_dict[procName+'MeVPerMIP'] = seq['mev_per_mip']
            config_dict[procName+'PEPerMIP'] = seq['pe_per_mip']
            config_dict[procName+'AttLength[m]'] = seq['strip_attenuation_length']
            config_dict[procName+'PosResolution[mm]'] = seq['strip_position_resolution']
        elif procName == "Overlay" :
            config_dict[procName+'BunchSpacing[ns]'] = seq['bunchSpacing']
            config_dict[procName+'DoPoissonIntime'] = seq['doPoissonIntime']
            config_dict[procName+'DoPoissonOutoftime'] = seq['doPoissonOutoftime']
            config_dict[procName+'NumberEarlierBunchesToSample'] = seq['nEarlierBunchesToSample']
            config_dict[procName+'NumberLaterBunchesToSample'] = seq['nLaterBunchesToSample']
            config_dict[procName+'TimeMean[ns]'] = seq['timeMean']
            config_dict[procName+'TimeSpread[ns]'] = seq['timeSpread']
            config_dict[procName+'TotalNumberOfInteractions'] = seq['totalNumberOfInteractions']
        elif procName == "TrigScintDigi" :
            config_dict[procName+'MeanNoiseSiPM'] = seq['mean_noise']
            config_dict[procName+'MeVPerMIP'] = seq['mev_per_mip']
            config_dict[procName+'PEPerMIP'] = seq['pe_per_mip']
        elif procName == "TrigScintCluster" :
            config_dict[procName+'MaxWidth'] = seq['max_cluster_width']
            config_dict[procName+'SeedThreshold'] = seq['seed_threshold']
            config_dict[procName+'MinThreshold'] = seq['clustering_threshold']
            config_dict[procName+'InputPassName'] = seq['input_pass_name']
        elif procName == "TrigScintTrack" :
            config_dict[procName+'MaxDelta'] = seq['delta_max']
            config_dict[procName+'SeedingCollection'] = seq['seeding_collection']
            config_dict[procName+'MinThreshold'] = seq['tracking_threshold']
            config_dict[procName+'InputPassName'] = seq['input_pass_name']
        elif procName == "TrackerHitKiller" :
            config_dict[procName+'Efficiency'] = seq['hitEfficiency']
        elif procName == "Trigger" and not "dqm" in seq['className'].split('::')[0] :
            if 'thresholds' in seq :
                config_dict[procName+'MaxEnergy[MeV]'] = seq['thresholds']
            else :
                config_dict[procName+'MaxEnergy[MeV]'] = seq['threshold']
            config_dict[procName+'EcalEndLayer'] = seq['end_layer']
            config_dict[procName+'EcalStartLayer'] = seq['start_layer']
        elif procName == "ElectronCounter" :
            if  seq['use_simulated_electron_number']:
                config_dict[procName+'UseSimElectronNb'] = True
                config_dict[procName+'InputColl'] = None
            else :
                config_dict[procName+'UseSimElectronNb'] = False
                config_dict[procName+'InputColl'] = seq['input_collection']+'_'+seq['input_pass_name']
            config_dict[procName+'SimElectronNb'] = seq['simulated_electron_number']
        elif procName == "FindableTrack" :
            config_dict[procName+'WasRun'] = 1
        elif procName == "TrackerVeto" :
            config_dict[procName+'WasRun'] = 1

    det = 'v{DetectorVersion}'.format(**in_conf)
    for cond in mjson['conditionsObjectProviders'] :
        if "RandomNumberSeedService" in cond['className'] :
            config_dict['RandomNumberSeedMode'] = cond['seedMode']
            config_dict['RandomNumberSeed'] = cond['seed']
        elif "Geometry" in cond['className'] :
            #print("Looking in "+cond['className'])
            #condName=cond['className'].split("::")[1]
            condName=cond['objectName']
#            condName=condName.replace("ldmx::", "")
            condName=condName.replace("Provider", "")#"HexReadout")
            #print("Using condName "+condName)
            if 'EcalHexReadout' in cond :
                config_dict[condName+'Gap[mm]'] = cond['EcalHexReadout'][det]['gap']
                config_dict[condName+'ModuleMinR[mm]'] = cond['EcalHexReadout'][det]['moduleMinR']
                config_dict[condName+'FrontZ[mm]'] = cond['EcalHexReadout'][det]['ecalFrontZ']
                config_dict[condName+'NumberCellRHeight[mm]'] = cond['EcalHexReadout'][det]['nCellRHeight']
            elif 'HcalGeometry' in cond and det in cond['HcalGeometry'] : 
                config_dict[condName+'ThicknessScint[mm]'] = cond['HcalGeometry'][det]['scint_thickness']
                config_dict[condName+'WidthScint[mm]'] = cond['HcalGeometry'][det]['scint_width']
                config_dict[condName+'EcalDx'] = cond['HcalGeometry'][det]['ecal_dx']
                config_dict[condName+'EcalDy'] = cond['HcalGeometry'][det]['ecal_dy']
                config_dict[condName+'NumSections'] = cond['HcalGeometry'][det]['num_sections']

                
        elif "conditions" in cond['className'] :
            if 'columns' in cond : 
                condName=cond['objectName']
                for col in range(len(cond['columns'])) :
                    config_dict[condName+'_'+cond['columns'][col]]=cond['entries'][0]["values"][col]

    config_dict['IsRecon'] = isRecon

    config_dict['ROOTCompressionSetting'] = mjson['compressionSetting'] if 'compressionSetting' in mjson else None 
    config_dict['PassName'] = mjson['passName']

    if 'maxEvents' in mjson and mjson['maxEvents'] > -1 :
        config_dict['NumberOfEvents'] = mjson['maxEvents']
        #otherwise we are most definitely using an input file and the number from there should be kept 

    logger.info(json.dumps(config_dict, indent = 2, sort_keys=True ))
    return config_dict


def job_starttime(starttime_f='.ldmx.job.starttime'):
    if os.path.exists(starttime_f):
        with open(starttime_f, 'r') as fd:
            return int(fd.read())
    else:
        current_time = int(time.time())
        with open(starttime_f, 'w') as fd:
            fd.write('{0}'.format(current_time))
            return current_time

def set_remote_output(conf_dict, meta):
    # Check for remote location and construct URL
    # GRID_GLOBAL_JOBHOST is available from ARC 6.8
    cehost = os.environ.get('GRID_GLOBAL_JOBHOST')
    with open('output.files', 'w') as f:
        if 'FinalOutputDestination' in conf_dict and 'FinalOutputBasePath' in conf_dict \
        and cehost not in conf_dict.get('NoUploadSites', '').split(','):
            filepath=""
            if 'IsEventLibrary' in meta and meta['IsEventLibrary']=='True' :
                #filepath = '/{Scope}/{BeamEnergy}GeV/{BatchID}/{name}'.format(**meta)
                filepath = '/{Scope}/{BeamEnergy}GeV/{BatchID}'.format(**meta)
            elif 'IsImage' in meta and meta['IsImage']=='True' :
                filepath = '/{UserID}/{Scope}/{JobID}'.format(**meta)
            else :
                filepath += '/{Scope}/v{DetectorVersion}/{BeamEnergy}GeV/{BatchID}'.format(**meta)
            pfn = conf_dict['FinalOutputBasePath']
            while pfn.endswith('/'):
                pfn = pfn[:-1]
            pfn += filepath+'/{name}'.format(**meta)
            meta['remote_output'] = {'rse': conf_dict['FinalOutputDestination'],
                                    'pfn': pfn}
            meta['DataLocation'] = pfn

            # If the "remote" site is actually local, skip uploading over gridftp,
            # after registering it with that url for other jobs to retrieve
            siteName=conf_dict['FinalOutputDestination'].split("_")[0].lower()
            logger.info("From output dest %s, got site name %s", conf_dict['FinalOutputDestination'], siteName)
            if siteName in cehost.lower() :
                filepath=os.environ['LDMX_STORAGE_BASE']+filepath
                pfn=filepath+'/{name}'.format(**meta)
                logger.info("At site %s, doing local copy of output file %s to final output destination", siteName, pfn )
                os.system('mkdir -p '+filepath)
                os.system('cp '+conf_dict['FileName']+' '+pfn)
            else :
                # Add to ARC output list
                f.write('{} {}'.format(conf_dict['FileName'], pfn))

def get_local_copy(conf_dict):
    for infile in conf_dict['InputDataLocationLocal'].split(",") : 
        logger.info("Copying local input file %s", infile )
        os.system('cp '+infile+' .')
        logger.info("Copied local input file %s to node", infile.split("/")[-1] )
    return

def get_pileup_file(conf_dict):
    fname=conf_dict['PileupFile'].split(":")[1]
    fullPath=conf_dict['PileupLocationLocal']
    logger.info("Dir contents before attempting to copy pileup file:")
    os.system('ls -lh')
    os.system('cp '+fullPath+' '+fname)
    logger.info("Dir contents after attempting to copy pileup file:")
    os.system('ls -lh')
    logger.info("Copied pileup file to node")
    return


def collect_image_meta( conf_dict):

    meta = {}
    meta['IsImage'] = True
    meta['IsSimulation'] = False
    # rucio specifics
    for fromconf in ['Scope', 'SampleId', 'JobID', 'FileName' ]:
        meta[fromconf] = conf_dict[fromconf] if fromconf in conf_dict else None
    # env
    if 'ACCOUNTING_WN_INSTANCE' in os.environ:
        meta['LdmxImage'] = os.environ['ACCOUNTING_WN_INSTANCE']
    elif 'SINGULARITY_IMAGE' in os.environ:
        meta['LdmxImage'] = os.environ['SINGULARITY_IMAGE'].split('/')[-1]
    else :
        meta['LdmxImage'] = None
    meta['ARCCEJobID'] = os.environ['GRID_GLOBAL_JOBID'].split('/')[-1] if 'GRID_GLOBAL_JOBID' in os.environ else None
    meta['FileCreationTime'] = int(time.time())
    meta['Walltime'] = meta['FileCreationTime'] - job_starttime()

    #for rucio, and for file naming?
    #start by setting up defaults 
    meta['G4version']='10.2.3_v0.4'
    meta['ROOTversion']='6.22.00' 
    meta['ONNXversion']='1.3.0'
    meta['XERCESversion']='3.2.3'
    meta['OSname']='UBUNTU'
    meta['OSversion']='18.04'
    for fromconf in ['G4version', 'ROOTversion', 'ONNXversion', 'XERCESversion', 'OSversion', 'OSname' ]:
        if fromconf in conf_dict :
            meta[fromconf] = conf_dict[fromconf] 

    # we want the imagge to end up in:
    # user case -- user.$USER.image:myImageName.sif
    # production case -- prod.image:ldmx-pro....
    #
    #  ... actually, this is a good time to leave this naming convention, and just use a short version tag also for prod images, so they are easy to look up/specify for later 
    #image='ldmx-{DockerRepo}_{DockerTag}-gLDMX.{G4version}-r{ROOTversion}-onnx{ONNXversion}-xerces{XERCESversion}-{OSname}{OSversion}.sif'.format(**meta)
    meta['UserID'] = "user."+os.environ['USER'] if os.environ['USER']!='admin' else "prod"
    meta['Scope'] = meta['UserID']+".image"
    meta['FileName'] =   meta['FileName']+".sif" if not ".sif" in meta['FileName'] #make sure the extension is there 
    meta['name'] =   meta['FileName'] #if os.environ['USER']!='admin' else image 

    # Check output file actually exists
    if not os.path.exists( os.environ['OUTPUTFILENAME'] ) : 
        logger.error('No output image exists!')
        sys.exit(1)

    conf_dict['FileName'] = meta['name']
    os.system('mv '+os.environ['OUTPUTFILENAME']+' '+ meta['name']
    set_remote_output(conf_dict, meta)
    if os.environ.get('KEEP_LOCAL_COPY'):
        data_location = os.environ['LDMX_STORAGE_BASE']
        data_location += '/ldmx/{Scope}/{BatchID}/{name}'.format(**meta)
        meta['local_replica'] = data_location
        if 'DataLocation' in meta:
            meta['DataLocation'] = ','.join([meta['DataLocation'], data_location])
        else:
            meta['DataLocation'] = data_location

    if not meta.get('DataLocation'):
        logger.error('No local or remote output location for output file, file will not be registered in Rucio')
        sys.exit(1)

    # Rucio metadata
    meta['scope'] = meta['Scope']
    meta['datasetscope'] = meta['Scope']
    meta['datasetname'] = meta['JobID']
    meta['containerscope'] = meta['Scope']
    meta['containername'] = meta['SampleId']

    meta['bytes'] = os.stat(conf_dict['FileName']).st_size
    (meta['md5'], meta['adler32']) = calculate_md5_adler32_checksum(conf_dict['FileName'])

    return meta



def collect_madgraph_meta( conf_dict):

    meta = {}
    meta['IsSimulation'] = True
    # madgraph library generation specifics 
    for fromconf in ['APrimeMass', 'NumberOfEvents', 'runNumber', 'IncidentEnergies', 'IsEventLibrary', 'BeamEnergy']:
        meta[fromconf] = conf_dict[fromconf] if fromconf in conf_dict else None
    # rucio specifics
    for fromconf in ['Scope', 'SampleId', 'BatchID', 'PhysicsProcess']:
        meta[fromconf] = conf_dict[fromconf] if fromconf in conf_dict else None
    # env
    if 'ACCOUNTING_WN_INSTANCE' in os.environ:
        meta['LdmxImage'] = os.environ['ACCOUNTING_WN_INSTANCE']
    elif 'SINGULARITY_IMAGE' in os.environ:
        meta['LdmxImage'] = os.environ['SINGULARITY_IMAGE'].split('/')[-1]
    else:
        meta['LdmxImage'] = None
    meta['ARCCEJobID'] = os.environ['GRID_GLOBAL_JOBID'].split('/')[-1] if 'GRID_GLOBAL_JOBID' in os.environ else None
    meta['FileCreationTime'] = int(time.time())
    meta['Walltime'] = meta['FileCreationTime'] - job_starttime()

    # the job run in the image sets up the output name like this:
    mgOutName = 'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}.tar.gz'.format(**meta)
    # just add the tid for our purposes 
    uniqueOutName = 'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}_t{FileCreationTime}.tar.gz'.format(**meta)
    # Check output file actually exists
    # TODO: this case should not return the metadata, but an error code   
    if not os.path.exists( mgOutName ) : #'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}.tar.gz'.format(**meta) ):
        logger.error('Output tarball does not exist!')
        return meta

    meta['name'] = uniqueOutName #'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}_t{FileCreationTime}.tar.gz'.format(**meta)
    conf_dict['FileName'] = meta['name']
    os.system('mv '+mgOutName+' '+uniqueOutName)
    set_remote_output(conf_dict, meta)
    if os.environ.get('KEEP_LOCAL_COPY'):
        data_location = os.environ['LDMX_STORAGE_BASE']
        data_location += '/ldmx/lheFiles/{Scope}/{BeamEnergy}GeV/{BatchID}/{name}'.format(**meta)
        meta['local_replica'] = data_location
        if 'DataLocation' in meta:
            meta['DataLocation'] = ','.join([meta['DataLocation'], data_location])
        else:
            meta['DataLocation'] = data_location

    if not meta.get('DataLocation'):
        logger.error('No local or remote output location for output file, file will not be registered in Rucio')
        return meta

    # Rucio metadata
    meta['scope'] = meta['Scope']
    meta['datasetscope'] = meta['Scope']
    meta['datasetname'] = meta['BatchID']
    meta['containerscope'] = meta['Scope']
    meta['containername'] = meta['SampleId']

    meta['bytes'] = os.stat(conf_dict['FileName']).st_size
    (meta['md5'], meta['adler32']) = calculate_md5_adler32_checksum(conf_dict['FileName'])

    return meta
    meta['ARCCEJobID'] = os.environ['GRID_GLOBAL_JOBID'].split('/')[-1] if 'GRID_GLOBAL_JOBID' in os.environ else None
    meta['FileCreationTime'] = int(time.time())
    meta['Walltime'] = meta['FileCreationTime'] - job_starttime()

    # the job run in the image sets up the output name like this:
    mgOutName = 'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}.tar.gz'.format(**meta)
    # just add the tid for our purposes 
    uniqueOutName = 'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}_t{FileCreationTime}.tar.gz'.format(**meta)
    # Check output file actually exists
    # TODO: this case should not return the metadata, but an error code   
    if not os.path.exists( mgOutName ) : #'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}.tar.gz'.format(**meta) ):
        logger.error('Output tarball does not exist!')
        return meta

    meta['name'] = uniqueOutName #'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}_t{FileCreationTime}.tar.gz'.format(**meta)
    conf_dict['FileName'] = meta['name']
    os.system('mv '+mgOutName+' '+uniqueOutName)
    set_remote_output(conf_dict, meta)
    if os.environ.get('KEEP_LOCAL_COPY'):
        data_location = os.environ['LDMX_STORAGE_BASE']
        data_location += '/ldmx/lheFiles/{Scope}/{BeamEnergy}GeV/{BatchID}/{name}'.format(**meta)
        meta['local_replica'] = data_location
        if 'DataLocation' in meta:
            meta['DataLocation'] = ','.join([meta['DataLocation'], data_location])
        else:
            meta['DataLocation'] = data_location

    if not meta.get('DataLocation'):
        logger.error('No local or remote output location for output file, file will not be registered in Rucio')
        return meta

    # Rucio metadata
    meta['scope'] = meta['Scope']
    meta['datasetscope'] = meta['Scope']
    meta['datasetname'] = meta['BatchID']
    meta['containerscope'] = meta['Scope']
    meta['containername'] = meta['SampleId']

    meta['bytes'] = os.stat(conf_dict['FileName']).st_size
    (meta['md5'], meta['adler32']) = calculate_md5_adler32_checksum(conf_dict['FileName'])

    return meta



def collect_meta(conf_dict, json_file):

    meta = collect_from_json(json_file, conf_dict)
    meta['IsSimulation'] = True

    # conf
    for fromconf in ['Scope', 'BatchID', 'PhysicsProcess', 'DetectorVersion', 'ElectronNumber', 'BeamEnergy']:
        try : 
            if not fromconf in meta :
                meta[fromconf] = conf_dict[fromconf] #if fromconf in conf_dict else None
        except Exception as e:
            logger.error('Failed to get mandatory key {} from job submission config: {}'.format(fromconf, str(e)))
            return meta
    if not 'BeamEnergy' in meta and 'BeamEnergy' in conf_dict : 
        meta['BeamEnergy'] = conf_dict['BeamEnergy']
        #else rely on it being copied..?
    if not 'SampleId' in meta :  #allow this to no longer being explicitly set, but compiled from the rest 
        meta['SampleId'] = 'v{}-{}GeV-{}e-{}'.format(meta['DetectorVersion'], meta['BeamEnergy'], meta['ElectronNumber'], meta['PhysicsProcess'])
    if not 'RunNumber' in meta and 'runNumber' in conf_dict :
        meta['RunNumber'] = conf_dict['runNumber']
    if not 'RandomSeed1' in meta and 'RandomSeed1' in conf_dict :
        meta['RandomSeed1'] = conf_dict['RandomSeed1']
    if not 'RandomSeed2' in meta and 'RandomSeed2' in conf_dict :
        meta['RandomSeed2'] = conf_dict['RandomSeed2']
    if ( not 'NumberOfEvents' in meta or meta['NumberOfEvents']<=0 ) and 'NumberOfEvents' in conf_dict :
        meta['NumberOfEvents'] = conf_dict['NumberOfEvents']
  
    meta['MagneticFieldmap'] = conf_dict['FieldMap'] if 'FieldMap' in conf_dict else None
    # env
    if 'ACCOUNTING_WN_INSTANCE' in os.environ:
        meta['LdmxImage'] = os.environ['ACCOUNTING_WN_INSTANCE']
    elif 'SINGULARITY_IMAGE' in os.environ:
        meta['LdmxImage'] = os.environ['SINGULARITY_IMAGE'].split('/')[-1]
    else:
        meta['LdmxImage'] = None
    meta['ARCCEJobID'] = os.environ['GRID_GLOBAL_JOBID'].split('/')[-1] if 'GRID_GLOBAL_JOBID' in os.environ else None
    meta['FileCreationTime'] = int(time.time())
    meta['Walltime'] = meta['FileCreationTime'] - job_starttime()


    # Check output file actually exists
    if not os.path.exists(conf_dict.get('FileName', '')):
        logger.error('Output file {} does not exist!'.format(conf_dict.get('FileName', '')))
        return meta
    if "hist_" in conf_dict.get('FileName') :
        meta['name'] = 'hist_{SampleId}_run{RunNumber}_t{FileCreationTime}.root'.format(**meta)
        meta['IsHistograms'] = True
        #consider setting this. don't want to confuse this with thinking it might be data though
        #meta['IsSimulation'] = False 
    else :
        meta['name'] = 'mc_{SampleId}_run{RunNumber}_t{FileCreationTime}.root'.format(**meta)
    set_remote_output(conf_dict, meta)
    if os.environ.get('KEEP_LOCAL_COPY'):
        data_location = os.environ['LDMX_STORAGE_BASE']
        data_location += '/ldmx/mc-data/{Scope}/v{DetectorVersion}/{BeamEnergy}GeV/{BatchID}/{name}'.format(**meta)
        meta['local_replica'] = data_location
        if 'DataLocation' in meta:
            meta['DataLocation'] = ','.join([meta['DataLocation'], data_location])
        else:
            meta['DataLocation'] = data_location

    if not meta.get('DataLocation'):
        logger.error('No local or remote output location for output file, file will not be registered in Rucio')
        return meta

    # Rucio metadata
    meta['scope'] = meta['Scope']
    meta['datasetscope'] = meta['Scope']
    meta['datasetname'] = meta['BatchID']
    meta['containerscope'] = meta['Scope']
    meta['containername'] = meta['SampleId']

    meta['bytes'] = os.stat(conf_dict['FileName']).st_size
    (meta['md5'], meta['adler32']) = calculate_md5_adler32_checksum(conf_dict['FileName'])

    return meta

def combine_meta( oldMeta, newMeta):
    # note: prinout level debug (here and below). default logger level is info, which hides this printout. 
    logger.debug('This should be input metadata:  {}'.format(oldMeta))

    metaOut={}
    #intialise all keys with values as pulled from the input file metadata
    inputMeta= (json.loads(oldMeta)).get("inputMeta")

    logger.debug('This should be copied metadata:  {}'.format(inputMeta))

    for key in inputMeta : 
        metaOut[key] = inputMeta[key]
        # special cases: singularity image used for input file is very important. make a new key with that
        # similarly, when continously reprocessing, need to keep track of what the input file was 
        if key == "InputFile" or key == "LdmxImage":
            if "EarlierStep"+key+"s"in metaOut :
                metaOut["EarlierStep"+key+"s"]+=", "+inputMeta[key]
            else :
                metaOut["EarlierStep"+key+"s"]=inputMeta[key]


    logger.info('This should be the current job metadata:  {}'.format(newMeta))

    #overwrite anything that has been updated
    for key in newMeta:
        metaOut[key] = newMeta[key]

    #here: if we're combining input files, the old number of events from them should be multiplied 
    if metaOut.get("NumberofEvents") :
        nEv=float(metaOut.get("NumberofEvents"))
        if metaOut.get("NumberInputFiles") :
            nFiles=int(newMeta.get("NumberInputFiles"))
            metaOut["CombinedNumberOfEvents"] = nEv*nFiles

    logger.debug('Final metadata:  {}'.format(metaOut))


    return metaOut 
    
# deprecated 
def combine_meta_fromFile( oldMetaFile, newMeta):
    metaOut={}
    #intialise all keys with values as pulled from the input file metadata
    with open(oldMetaFile, 'r') as meta_f:
        for contents in meta_f:
            contents=contents.replace("{","")
            contents=contents.replace("}","")
            #        print("Opened input metadata file")
            #        metaOut = json.load( meta_f )
            for line in contents.split(',') :
#                print line
                #            for line in contents[0]:
                line=line.replace("\"", "")
                line=line.replace(" ", "")
                kv = line.split(':', 2)
                if len(kv) != 2:
                    logger.error('Malformed %s line: %s', oldMetaFile, line)
                    continue
                metaOut[kv[0]] = kv[1].strip()
                #print (kv[0])
                #print (metaOut[kv[0]])
#    print ("Old meta")
#    json.dumps( metaOut, indent = 2, sort_keys=True  )
#    print ("\n\n")
#    print ("New meta")
#    json.dumps( newMeta, indent = 2, sort_keys=True  )
#    print ("\n\n")

    #overwrite anything that has been updated
    for key in newMeta:
        metaOut[key] = newMeta[key]
        print (key+"   "+str(metaOut[key]))
    print ("Combined meta")
    json.dumps( metaOut, indent = 2, sort_keys=True  )
    print ("\n\n")

    return metaOut 
    


def get_parser():
    parser = argparse.ArgumentParser(description='LDMX Production Simulation Helper')
    parser.add_argument('-d', '--debug', action='store', default='INFO',
                        choices=['CRITICAL', 'ERROR', 'WARNING', 'INFO', 'DEBUG'],
                        help='verbosity level (default is %(default)s)')
    parser.add_argument('-c', '--config', action='store', default='ldmxjob.config',
                        help='LDMX Production simulation job config file')
    parser.add_argument('-t', '--template', action='store', default='ldmxsim.mac.template',
                        help='LDMX Production simulation macro-definition file template')
    parser.add_argument('-m', '--metaDump', action='store', default='parameterDump.json',
                        help='LDMX Production simulation parameter dump JSON file')
    parser.add_argument('-i', '--inputMeta', action='store', default='', #'inputMeta.json',
                        help='Retrieved Rucio metadata JSON file (associated with job input file)')
    parser.add_argument('-j', '--json-metadata', action='store', default='rucio.metadata',
                        help='LDMX Production simulation JSON metadata file')
    parser.add_argument('-I', '--makeImage', action='store', default=False,
                        help='boolean flag to indicate a singularity image build job')

    parser.add_argument('action', choices=['init', 'copy-local', 'collect-metadata', 'collect-metadata-madgraph', 'collect-metadata-image', 'test'],
                        help='Helper action to perform')
    return parser


if __name__ == '__main__':
    # parse arguments
    cmd_args = get_parser().parse_args()
    loglevel = getattr(logging, cmd_args.debug, 30)
    logger.setLevel(loglevel)

    makeImage=False 
    if cmd_args.makeImage : #running an image building job, rather than production
        makeImage=True 
    # config is parsed the same way for any action... except image building which is very different 
    if makeImage :
        conf_dict = parse_ldmx_imagebuild_config(cmd_args.config)
    else :
        conf_dict = parse_ldmx_config(cmd_args.config)

    # metadata extraction from job parameter dump: note, in local test mode, we pull input metadata from a file 
    if cmd_args.action == 'test' :
        meta = collect_from_json( cmd_args.metaDump, conf_dict )
        if cmd_args.inputMeta :
            print("Running combine_meta with "+cmd_args.inputMeta )
            with open(cmd_args.inputMeta, 'r') as meta_f :
                inMeta=(json.load(meta_f)).get("inputMeta")
#                meta=combine_meta( inMeta, meta ) # doesn't work! has to be passed as a dict
                meta=combine_meta( json.dumps(inMeta), meta )

        #print result to screen 
        json.dumps( meta, indent = 2, sort_keys=True )
        with open(cmd_args.json_metadata, 'w') as meta_f:
            json.dump( meta, meta_f, sort_keys=True )
    elif cmd_args.action == 'init':
        # store job start time
        job_starttime()
        # print values for bash eval
        print_eval(conf_dict, makeImage)
    elif cmd_args.action == 'copy-local':
        if 'InputDataLocationLocalRSE' in conf_dict :
            if not conf_dict['InputDataLocationLocalRSE'].split(",")[0] == 'None'  :
                get_local_copy( conf_dict )
# turns out this is not needed
#        if 'PileupLocationLocal' in conf_dict :
#            get_pileup_file( conf_dict )
    
    elif cmd_args.action == 'collect-metadata-madgraph':
        meta = collect_madgraph_meta(conf_dict)
        with open(cmd_args.json_metadata, 'w') as meta_f:
            json.dump(meta, meta_f)
    elif cmd_args.action == 'collect-metadata-image':
        meta = collect_image_meta(conf_dict)
        with open(cmd_args.json_metadata, 'w') as meta_f:
            json.dump(meta, meta_f)
            
    elif cmd_args.action == 'collect-metadata':
        meta = collect_meta(conf_dict, cmd_args.metaDump)
        if 'local_replica' in meta:
            print('export FINALOUTPUTFILE="{local_replica}"'.format(**meta))

        if 'PileupFile' in conf_dict :
            #pull the pileup file name from the job meta
            meta['PileupFile'] = conf_dict.get('PileupFile')

        if 'InputMetadata' in conf_dict :
            #first, make sure to copy over the input file name to the output meta data 
            meta['InputFile'] = conf_dict.get('InputFile')
            # combine the current job's metadata (meta) with the old one (inputMeta)
            meta=combine_meta( conf_dict.get('InputMetadata'), meta )
            #meta=combine_meta( (conf_dict.get('InputMetadata')).get("inputMeta"), meta )
        with open(cmd_args.json_metadata, 'w') as meta_f:
            json.dump(meta, meta_f)


