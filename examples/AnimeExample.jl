#ENV["JULIA_CONDAPKG_BACKEND"] = "Null" # uncomment to never install Conda packages if an external custom Conda environment is desired

using ArgParse
using Logging
using HDF5
using YAML

include("../src/Anime.jl")
using .Anime

# create argument parser
function create_parser()
    s = ArgParseSettings()

    @add_arg_table s begin
        "config"
            help = "Input YAML file name with observation configuration"
            required = true
        "outdir"
            help = "Directory to hold output products"
            required = true
        "--clobber", "-c"
            action = :store_true
            help = "Delete and create output directory anew"
    end

    return parse_args(s)
end

# create parser
args = create_parser()

# change working directory to the user-specified output directory
startdir = pwd() # store original working directory
config = abspath(startdir, args["config"])
outdir = abspath(startdir, args["outdir"])

# create a new empty output directory
if isdir(outdir)
    if args["clobber"]
        run(`rm -rf $(outdir)`)
	mkdir(outdir)
    else 
	error("$outdir exists but -c option is not given 🤷") 
    end
else
    mkdir(outdir)
end
@info("Changing working directory to $outdir")
cd(outdir)

y = YAML.load_file(config, dicttype=Dict{String,Any}) # load YAML config file
h5file = "insmodel.h5"

# generate new MS
if y["mode"] == "manual"
    msfromconfig(y["msname"], y["mode"], y["stations"], y["casaanttemplate"], y["spw"]["centrefreq"], y["spw"]["bandwidth"], y["spw"]["channels"],
    y["source"], y["starttime"], y["exposure"], y["scans"], y["scanlengths"], y["scanlag"]; autocorr=y["autocorr"], telescopename=y["telescopename"],
    feed=y["feed"], shadowlimit=y["shadowlimit"], elevationlimit=y["elevationlimit"], stokes=y["stokes"], delim=",", ignorerepeated=false)

elseif y["mode"] == "uvfits"
    msfromuvfits(y["uvfits"], y["msname"], y["mode"], y["stations"], delim=",", ignorerepeated=false)
else
    error("MS generation mode '$(y["mode"])' not recognised 🤷")
end

# call wscean to compute source coherency
run_wsclean(y["msname"], y["skymodel"], y["polarized"], y["channelgroups"], y["osfactor"])

# load ms data into custom struct
obs = loadms(y["msname"], y["stations"], Int(y["corruptseed"]), Int(y["troposphere"]["tropseed"]), y["troposphere"]["wetonly"], y["correff"],
y["troposphere"]["attenuate"], y["troposphere"]["skynoise"], y["troposphere"]["meandelays"], y["troposphere"]["turbulence"],
y["instrumentalpol"]["visibilityframe"], y["instrumentalpol"]["mode"], y["pointing"]["interval"], y["pointing"]["mode"], y["stationgains"]["mode"],
y["bandpass"]["bandpassfile"], delim=",", ignorerepeated=false)

# plot uv-coverage
y["diagnostics"] && plotuvcov(obs.uvw, obs.flagrow, obs.chanfreqvec)

# make diagnostic plots of uncorrupted data
y["diagnostics"] && plotvis(obs.uvw, obs.chanfreqvec, obs.flag, obs.data, obs.numchan, obs.times, plotphases=true, saveprefix="modelvis_")

# add tropospheric effects
y["troposphere"]["enable"] && troposphere(obs, h5file)

# add instrumental polarization
if y["instrumentalpol"]["enable"]
    instrumentalpol(obs.scanno, obs.times, obs.stationinfo, obs.phasedir, obs.pos, obs.data, obs.numchan, obs.polframe,
    obs.polmode, obs.antenna1, obs.antenna2, obs.exposure, obs.rngcorrupt, h5file=h5file)
    y["diagnostics"] && plotelevationangle(h5file, obs.scanno, obs.times, obs.stationinfo.station)
end

# add pointing errors
if y["pointing"]["enable"]
    pointing(obs.stationinfo, obs.scanno, obs.chanfreqvec, obs.ptginterval, obs.ptgmode, obs.exposure, obs.times, obs.rngcorrupt,
    obs.antenna1, obs.antenna2, obs.data, obs.numchan, h5file=h5file)
    y["diagnostics"] && plotpointingerrors(h5file, obs.scanno, obs.stationinfo.station)
end

# add station gains
if y["stationgains"]["enable"]
    stationgains(obs.scanno, obs.times, obs.exposure, obs.data, obs.stationinfo, obs.stationgainsmode,
    obs.rngcorrupt, obs.antenna1, obs.antenna2, obs.numchan, h5file=h5file)
    y["diagnostics"] && plotstationgains(h5file, obs.scanno, obs.times, obs.stationinfo.station)
end

# add bandpasses
if y["bandpass"]["enable"]
    bandpass(obs.bandpassfile, obs.data, obs.stationinfo, obs.rngcorrupt, obs.antenna1, obs.antenna2,
    obs.numchan, obs.chanfreqvec, h5file=h5file)
    y["diagnostics"] && plotbandpass(h5file, obs.stationinfo.station, obs.chanfreqvec)
end

# add thermal noise
y["thermalnoise"]["enable"] && thermalnoise(obs.times, obs.antenna1, obs.antenna2, obs.data,
y["correff"], obs.exposure, obs.chanwidth, obs.rngcorrupt, obs.stationinfo.sefd_Jy, h5file=h5file)

# make diagnostic plots
y["diagnostics"] && plotvis(obs.uvw, obs.chanfreqvec, obs.flag, obs.data, obs.numchan, obs.times, saveprefix="datavis_") 

# compute weights and write everything to disk
postprocessms(obs, h5file=h5file)

# Change back to original working directory
@info("Changing working directory back to $startdir")
cd(startdir)
@info("Anime.jl observation completed successfully 📡")