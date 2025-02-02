export parallacticangle, elevationangle

"""
    parallacticangle(times::Vector{Float64}, phasedir::Array{Float64,2}, stationinfo::DataFrame, pos::Array{Float64,2})

Compute parallactic angle for all stations in `stationinfo` for all `times` using `phasedir` and `pos` information.
"""
function parallacticangle(times::Vector{Float64}, phasedir::Array{Float64,2}, stationinfo::DataFrame, pos::Array{Float64,2})
    # get unique times
    uniqtimes = unique(times)

    ra = qa.quantity(phasedir[1], "rad")
    dec = qa.quantity(phasedir[2], "rad")

    pointing = me.direction("j2000", ra, dec)
    starttime = me.epoch("utc", qa.quantity(uniqtimes[1], "s"))
    me.doframe(starttime)

    nant = size(stationinfo)[1]

    parallacticanglematrix = zeros(size(uniqtimes)[1], nant)

    for ant in 1:nant
        x = qa.quantity(pos[1, ant], "m")
        y = qa.quantity(pos[2, ant], "m")
        z = qa.quantity(pos[3, ant], "m")
        position = me.position("wgs84", x, y, z)
        me.doframe(position)
        sec2rad = 2*pi/(24.0*3600.0)
        hourangle = pyconvert(Float64, me.measure(pointing, "HADEC")["m0"]["value"]) .+ (uniqtimes.-minimum(uniqtimes)).*sec2rad
        earthradius = 6371000.0
        latitude = asin(pos[3, ant]/earthradius)
	parallacticanglematrix[:,ant] = atan.(sin.(hourangle).*cos(latitude), (cos(phasedir[2])*sin(latitude).-cos.(hourangle).*cos(latitude).*sin(phasedir[2])))
    end

    return parallacticanglematrix
end

"""
    elevationangle(times::Vector{Float64}, phasedir::Array{Float64,2}, stationinfo::DataFrame, pos::Array{Float64, 2})

Compute elevation angle for all stations in `stationinfo` for all `times` using `phasedir` and `pos` information.
"""
function elevationangle(times::Vector{Float64}, phasedir::Array{Float64,2}, stationinfo::DataFrame, pos::Array{Float64, 2})
    # get unique times
    uniqtimes = unique(times)

    ra = qa.quantity(phasedir[1], "rad")
    dec = qa.quantity(phasedir[2], "rad")
    
    pointing = me.direction("j2000", ra, dec)
    starttime = me.epoch("utc", qa.quantity(uniqtimes[1], "s"))
    me.doframe(starttime)

    nant = size(stationinfo)[1]
    
    elevationmatrix = zeros(size(uniqtimes)[1], nant)
    
    for ant in 1:nant
        x = qa.quantity(pos[1, ant], "m")
        y = qa.quantity(pos[2, ant], "m")
        z = qa.quantity(pos[3, ant], "m")
        position = me.position("wgs84", x, y, z)
        me.doframe(position)
        sec2rad = 2*pi/(24.0*3600.0)
        hourangle = pyconvert(Float64, me.measure(pointing, "HADEC")["m0"]["value"]) .+ (uniqtimes.-minimum(uniqtimes)).*sec2rad
        earthradius = 6371000.0
        latitude = asin(pos[3, ant]/earthradius)
        elevationmatrix[:,ant] = asin.(sin(latitude)*sin(phasedir[2]).+cos(latitude)*cos(phasedir[2]).*cos.(hourangle))
    end

    elevationmatrix[elevationmatrix .< 0] .= 0.0 # set all -ve values to 0.0 instead of NaN # set all negative values to NaN
    return elevationmatrix
end
