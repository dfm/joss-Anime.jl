export parallacticangle, elevationangle, gentimeseries

quanta = pyimport("casatools" => "quanta")
qa = quanta()

me = measures()

function parallacticangle(obs::CjlObservation)
    """
    Compute parallactic angle for each antenna for all times
    """
    # get unique times
    uniqtimes = unique(obs.times)

    ra = qa.quantity(obs.phasedir[1], "rad")
    dec = qa.quantity(obs.phasedir[2], "rad")

    pointing = me.direction("j2000", ra, dec)
    starttime = me.epoch("utc", qa.quantity(uniqtimes[1], "s"))
    me.doframe(starttime)

    nant = size(obs.stationinfo)[1]

    parallacticanglematrix = zeros(size(uniqtimes)[1], nant)

    for ant in 1:nant
        x = qa.quantity(obs.pos[1, ant], "m")
        y = qa.quantity(obs.pos[2, ant], "m")
        z = qa.quantity(obs.pos[3, ant], "m")
        position = me.position("wgs84", x, y, z)
        me.doframe(position)
        sec2rad = 2*pi/(24.0*3600.0)
        hourangle = pyconvert(Float64, me.measure(pointing, "HADEC")["m0"]["value"]) .+ (uniqtimes.-minimum(uniqtimes)).*sec2rad
        earthradius = 6371000.0
        latitude = asin(obs.pos[3, ant]/earthradius)
	parallacticanglematrix[:,ant] = atan.(sin.(hourangle).*cos(latitude), (cos(obs.phasedir[2])*sin(latitude).-cos.(hourangle).*cos(latitude).*sin(obs.phasedir[2])))
    end

    return parallacticanglematrix
end

function elevationangle(obs::CjlObservation)
    """
    Compute elevation angle for each antenna for all times
    """
    # get unique times
    uniqtimes = unique(obs.times)

    ra = qa.quantity(obs.phasedir[1], "rad")
    dec = qa.quantity(obs.phasedir[2], "rad")
    
    pointing = me.direction("j2000", ra, dec)
    starttime = me.epoch("utc", qa.quantity(uniqtimes[1], "s"))
    me.doframe(starttime)

    nant = size(obs.stationinfo)[1]
    
    elevationmatrix = zeros(size(uniqtimes)[1], nant)
    
    for ant in 1:nant
        x = qa.quantity(obs.pos[1, ant], "m")
        y = qa.quantity(obs.pos[2, ant], "m")
        z = qa.quantity(obs.pos[3, ant], "m")
        position = me.position("wgs84", x, y, z)
        me.doframe(position)
        sec2rad = 2*pi/(24.0*3600.0)
        hourangle = pyconvert(Float64, me.measure(pointing, "HADEC")["m0"]["value"]) .+ (uniqtimes.-minimum(uniqtimes)).*sec2rad
        earthradius = 6371000.0
        latitude = asin(obs.pos[3, ant]/earthradius)
        elevationmatrix[:,ant] = asin.(sin(latitude)*sin(obs.phasedir[2]).+cos(latitude)*cos(obs.phasedir[2]).*cos.(hourangle))
    end

    return elevationmatrix
end

function gentimeseries(mode::String, location::ComplexF32, scale::Float64, driftrate::Float64, nsamples::Int64, rng::AbstractRNG)
    """
    Generate complex-valued wiener series
    """
    # TODO this is a crude version of a wiener process -- to be updated
    series = zeros(ComplexF32, nsamples)
    if mode == "wiener"
        sqrtnsamples = sqrt(nsamples)
        series[1] = location + scale*randn(rng, ComplexF32)
        for ii in 2:nsamples
            series[ii] = series[ii-1] + (scale*randn(rng, ComplexF32)/sqrtnsamples) + driftrate*ii
        end
    elseif mode == "gaussian"
        series = location .+ scale*randn(rng, ComplexF32, nsamples)
    end
    return series
end

function gentimeseries(mode::String, location::Float32, scale::Float64, driftrate::Float64, nsamples::Int64, rng::AbstractRNG)
    """
    Generate complex-valued wiener series
    """
    # TODO this is a crude version of a wiener process -- to be updated
    series = zeros(Float32, nsamples)
    if mode == "wiener"
        sqrtnsamples = sqrt(nsamples)
        series[1] = location + scale*randn(rng, Float32)
        for ii in 2:nsamples
            series[ii] = series[ii-1] + (scale*randn(rng, Float32)/sqrtnsamples) + driftrate*ii
        end
    elseif mode == "gaussian"
        series = location .+ scale*randn(rng, Float32, nsamples)
    end
    return series
end
