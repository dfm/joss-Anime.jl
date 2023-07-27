@testset "Troposphere" begin
    y = YAML.load_file("data/testconfig.yaml", dicttype=Dict{String,Any}) # sample dict to test loadms()

    obs = loadms(y["msname"], y["stations"], Int(y["corruptseed"]), Int(y["troposphere"]["tropseed"]), y["troposphere"]["wetonly"], y["correff"], 
    y["troposphere"]["attenuate"], y["troposphere"]["skynoise"], y["troposphere"]["meandelays"], y["troposphere"]["turbulence"], 
    y["instrumentalpol"]["visibilityframe"], y["instrumentalpol"]["mode"], y["pointing"]["interval"], y["pointing"]["mode"], y["stationgains"]["mode"], 
    y["bandpass"]["bandpassfile"], delim=",", ignorerepeated=false)

    @inferred Anime.run_atm(obs, absorptionfile="data/absorption.csv", dispersivefile="data/dispersive.csv")

    rm("atm.csv")
end

@testset "Polarization" begin
    y = YAML.load_file("data/testconfig.yaml", dicttype=Dict{String,Any}) # sample dict to test loadms()
    h5file = "inspol.h5"

    obs = loadms(y["msname"], y["stations"], Int(y["corruptseed"]), Int(y["troposphere"]["tropseed"]), y["troposphere"]["wetonly"], y["correff"], 
    y["troposphere"]["attenuate"], y["troposphere"]["skynoise"], y["troposphere"]["meandelays"], y["troposphere"]["turbulence"], 
    y["instrumentalpol"]["visibilityframe"], y["instrumentalpol"]["mode"], y["pointing"]["interval"], y["pointing"]["mode"], y["stationgains"]["mode"], 
    y["bandpass"]["bandpassfile"], delim=",", ignorerepeated=false)

    @inferred instrumentalpol(obs.scanno, obs.times, obs.stationinfo, obs.phasedir, obs.pos, obs.data, obs.numchan, obs.polframe,
    obs.polmode, obs.antenna1, obs.antenna2, obs.exposure, obs.rngcorrupt, h5file=h5file, elevfile="data/insmodel.h5", parangfile="data/insmodel.h5")

    rm(h5file)
end

@testset "Primary Beam" begin
    y = YAML.load_file("data/testconfig.yaml", dicttype=Dict{String,Any}) # sample dict to test loadms()
    h5file = "beam.h5"

    obs = loadms(y["msname"], y["stations"], Int(y["corruptseed"]), Int(y["troposphere"]["tropseed"]), y["troposphere"]["wetonly"], y["correff"], 
    y["troposphere"]["attenuate"], y["troposphere"]["skynoise"], y["troposphere"]["meandelays"], y["troposphere"]["turbulence"], 
    y["instrumentalpol"]["visibilityframe"], y["instrumentalpol"]["mode"], y["pointing"]["interval"], y["pointing"]["mode"], y["stationgains"]["mode"], 
    y["bandpass"]["bandpassfile"], delim=",", ignorerepeated=false)

    @inferred pointing(obs.stationinfo, obs.scanno, obs.chanfreqvec, obs.ptginterval, obs.ptgmode, obs.exposure, obs.times, obs.rngcorrupt,
    obs.antenna1, obs.antenna2, obs.data, obs.numchan, h5file=h5file)

    rm(h5file)
end

@testset "Station Gains" begin
    y = YAML.load_file("data/testconfig.yaml", dicttype=Dict{String,Any}) # sample dict to test loadms()
    h5file = "gains.h5"

    obs = loadms(y["msname"], y["stations"], Int(y["corruptseed"]), Int(y["troposphere"]["tropseed"]), y["troposphere"]["wetonly"], y["correff"], 
    y["troposphere"]["attenuate"], y["troposphere"]["skynoise"], y["troposphere"]["meandelays"], y["troposphere"]["turbulence"], 
    y["instrumentalpol"]["visibilityframe"], y["instrumentalpol"]["mode"], y["pointing"]["interval"], y["pointing"]["mode"], y["stationgains"]["mode"], 
    y["bandpass"]["bandpassfile"], delim=",", ignorerepeated=false)

    @inferred stationgains(obs.scanno, obs.times, obs.exposure, obs.data, obs.stationinfo, obs.stationgainsmode,
    obs.rngcorrupt, obs.antenna1, obs.antenna2, obs.numchan, h5file=h5file)

    rm(h5file)
end

@testset "Bandpass" begin
    y = YAML.load_file("data/testconfig.yaml", dicttype=Dict{String,Any}) # sample dict to test loadms()
    h5file = "bandpass.h5"

    obs = loadms(y["msname"], y["stations"], Int(y["corruptseed"]), Int(y["troposphere"]["tropseed"]), y["troposphere"]["wetonly"], y["correff"], 
    y["troposphere"]["attenuate"], y["troposphere"]["skynoise"], y["troposphere"]["meandelays"], y["troposphere"]["turbulence"], 
    y["instrumentalpol"]["visibilityframe"], y["instrumentalpol"]["mode"], y["pointing"]["interval"], y["pointing"]["mode"], y["stationgains"]["mode"], 
    y["bandpass"]["bandpassfile"], delim=",", ignorerepeated=false)

    @inferred bandpass(obs.bandpassfile, obs.data, obs.stationinfo, obs.rngcorrupt, obs.antenna1, obs.antenna2,
    obs.numchan, obs.chanfreqvec, h5file=h5file)

    rm(h5file)
end

@testset "Noise" begin
    y = YAML.load_file("data/testconfig.yaml", dicttype=Dict{String,Any}) # sample dict to test loadms()
    h5file = "noise.h5"

    obs = loadms(y["msname"], y["stations"], Int(y["corruptseed"]), Int(y["troposphere"]["tropseed"]), y["troposphere"]["wetonly"], y["correff"], 
    y["troposphere"]["attenuate"], y["troposphere"]["skynoise"], y["troposphere"]["meandelays"], y["troposphere"]["turbulence"], 
    y["instrumentalpol"]["visibilityframe"], y["instrumentalpol"]["mode"], y["pointing"]["interval"], y["pointing"]["mode"], y["stationgains"]["mode"], 
    y["bandpass"]["bandpassfile"], delim=",", ignorerepeated=false)

    @inferred thermalnoise(obs.times, obs.antenna1, obs.antenna2, obs.data, y["correff"], obs.exposure, obs.chanwidth, obs.rngcorrupt, 
    obs.stationinfo.sefd_Jy, h5file=h5file)

    rm(h5file)
end