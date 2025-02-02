export stationgains!

"""
    stationgains!(data::Array{Complex{Float32},4}, scanno::Vector{Int32}, times::Vector{Float64}, exposure::Float64, 
    stationinfo::DataFrame, mode::String, corruptseed::Int, antenna1::Vector{Int32}, antenna2::Vector{Int32}, numchan::Int64; h5file::String="")

Compute time-variable complex station gains and apply to data; write model to HDF5 file.
"""
function stationgains!(data::Array{Complex{Float32},4}, scanno::Vector{Int32}, times::Vector{Float64}, exposure::Float64, 
    stationinfo::DataFrame, mode::String, corruptseed::Int, antenna1::Vector{Int32}, antenna2::Vector{Int32}, numchan::Int64; h5file::String="")
    @info("Computing station gains...")
    # initialize RNG with seed
    rngcorrupt = Xoshiro(corruptseed)

    # open h5 file for writing
    if !isempty(h5file)
        fid = h5open(h5file, "cw")
        g = create_group(fid, "stationgains")
        HDF5.attributes(g)["desc"] = "Numerical values of time-variable per station G-Jones terms applied to data"
        HDF5.attributes(g)["dims"] = "2 x 2 x ntimes_per_scan x nant" #for each scan, a 4d array of 2 x 2 x ntime x nant is stored
    end

    # get unique scan numbers
    uniqscans = unique(scanno)

    # loop through each station to create a vector of 2x2 G-Jones terms evolving over time
    # TODO parametrise in terms of gain ratio
    row = 1 # variable to index data array
    for scan in uniqscans
        # compute ideal ntimes per scan
        actualtscanvec = unique(getindex(times, findall(scanno.==scan)))
    	actualtscanveclen = length(actualtscanvec)
	    idealtscanvec = collect(first(actualtscanvec):exposure:last(actualtscanvec))
	    idealtscanveclen = length(idealtscanvec)

	    # create 4d array to hold G-Jones terms per time per station
	    gjonesmatrices = zeros(eltype(data), 2, 2, idealtscanveclen, size(stationinfo)[1]) # 2 x 2 x ntimes x nant
        gjonesr = zeros(Float32, idealtscanveclen)
        gjonesθ = zeros(Float32, idealtscanveclen)

	    for ant in eachindex(stationinfo.station)
            #gjonesmatrices[1, 1, :, ant] = genseries1d!(gjonesmatrices[1, 1, :, ant], mode, stationinfo.g_pol1_loc[ant], real(stationinfo.g_pol1_scale[ant]), Float32(0.0), idealtscanveclen, rngcorrupt)
	        #gjonesmatrices[2, 2, :, ant] = genseries1d!(gjonesmatrices[2, 2, :, ant], mode, stationinfo.g_pol2_loc[ant], real(stationinfo.g_pol2_scale[ant]), Float32(0.0), idealtscanveclen, rngcorrupt)

            # get amplitude and phase of the mean and std for pol1
            amplmean1 = Float32(abs(stationinfo.g_pol1_loc[ant]))
            amplstd1 = Float32(abs(stationinfo.g_pol1_scale[ant]))
            phasemean1 = Float32(angle(stationinfo.g_pol1_loc[ant]))
            phasestd1 = Float32(angle(stationinfo.g_pol1_scale[ant]))

            # generate time series for amplitudes and phases independently
            gjonesr[:] = genseries1d!(gjonesr, idealtscanvec, rngcorrupt, μ=amplmean1, σ=amplstd1, ρ=actualtscanvec[end]-actualtscanvec[begin])
            gjonesθ[:] = genseries1d!(gjonesθ, mode, phasemean1, phasestd1, Float32(0.0), idealtscanveclen, rngcorrupt)

            # convert back to Cartesian form and write to gjonesmatrix
            reals = gjonesr .* cos.(gjonesθ)
            imags = gjonesr .* sin.(gjonesθ)
            gjonesmatrices[1, 1, :, ant] = [complex(r, i) for (r, i) in zip(reals, imags)]

            # get amplitude and phase of the mean and std for pol2
            amplmean2 = Float32(abs(stationinfo.g_pol2_loc[ant]))
            amplstd2 = Float32(abs(stationinfo.g_pol2_scale[ant]))
            phasemean2 = Float32(angle(stationinfo.g_pol2_loc[ant]))
            phasestd2 = Float32(angle(stationinfo.g_pol2_scale[ant]))

            # generate time series for amplitudes and phases independently
            gjonesr[:] = genseries1d!(gjonesr, idealtscanvec, rngcorrupt, μ=amplmean2, σ=amplstd2, ρ=actualtscanvec[end]-actualtscanvec[begin])
            gjonesθ[:] = genseries1d!(gjonesθ, mode, phasemean2, phasestd2, Float32(0.0), idealtscanveclen, rngcorrupt)

            # convert back to Cartesian form and write to gjonesmatrix
            reals = gjonesr .* cos.(gjonesθ)
            imags = gjonesr .* sin.(gjonesθ)
            gjonesmatrices[2, 2, :, ant] = [complex(r, i) for (r, i) in zip(reals, imags)]
	    end

        # loop over time/row and apply gjones terms corresponding to each baseline
	    findnearest(A,x) = argmin(abs.(A .- x)) # define function to find nearest neighbour
        for t in 1:actualtscanveclen
            idealtimeindex = findnearest(idealtscanvec, actualtscanvec[t])
            # read all baselines present in a given time
            ant1vec = getindex(antenna1, findall(times.==actualtscanvec[t]))
            ant2vec = getindex(antenna2, findall(times.==actualtscanvec[t]))
            for (ant1,ant2) in zip(ant1vec, ant2vec)
                for chan in 1:numchan
                    data[:,:,chan,row] = gjonesmatrices[:,:,idealtimeindex,ant1+1]*data[:,:,chan,row]*adjoint(gjonesmatrices[:,:,idealtimeindex,ant2+1])
                end
                row += 1 # increment data last index i.e. row number
            end
        end

	    # write to h5 file
        if !isempty(h5file)
	        g["gjones_scan$(scan)"] = gjonesmatrices
        end
    end

    # add datatype attribute
    if !isempty(h5file)
        HDF5.attributes(g)["datatype"] = string(typeof(read(g[keys(g)[1]])))
        close(fid)
    end

    
    @info("Compute and apply station gains 🙆")
end

"""
    stationgains!(ms::MeasurementSet, stationinfo::DataFrame, obsconfig::Dict; h5file::String="")

Alias for use in pipelines.
"""
function stationgains!(ms::MeasurementSet, stationinfo::DataFrame, obsconfig::Dict; h5file::String="")
    stationgains!(ms.data, ms.scanno, ms.times, ms.exposure, stationinfo, obsconfig["stationgains"]["mode"],
    obsconfig["corruptseed"], ms.antenna1, ms.antenna2, ms.numchan, h5file=h5file)
end