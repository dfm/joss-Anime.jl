export instrumentalpolarization!

"""
    instrumentalpolarization!(data::Array{Complex{Float32},4}, scanno::Vector{Int32}, times::Vector{Float64},
    stationinfo::DataFrame, phasedir::Array{Float64,2}, pos::Array{Float64, 2}, chanfreqvec::Vector{Float64}, polframe::String,
    polmode::String, antenna1::Vector{Int32}, antenna2::Vector{Int32}, exposure::Float64, corruptseed::Int; h5file::String="",
    elevfile::String="", parangfile::String="")

Compute frequency-varying instrumental polarization (leakage, or "D-Jones" terms) and apply to data; write model to HDF5 file.
"""
function instrumentalpolarization!(data::Array{Complex{Float32},4}, scanno::Vector{Int32}, times::Vector{Float64},
    stationinfo::DataFrame, phasedir::Array{Float64,2}, pos::Array{Float64, 2}, chanfreqvec::Vector{Float64}, polframe::String,
    polmode::String, antenna1::Vector{Int32}, antenna2::Vector{Int32}, exposure::Float64, corruptseed::Int; h5file::String="",
    elevfile::String="", parangfile::String="")
    @info("Computing polarization models...")
    # initialize RNG with seed
    rngcorrupt = Xoshiro(corruptseed)

    # get unique scan numbers
    uniqscans = unique(scanno)

    # get unique times
    uniqtimes = unique(times)
    ntimes = size(uniqtimes)[1]

    # get numchan
    numchan = length(chanfreqvec)

    # compute necessary quantities
    if elevfile != "" && isfile(elevfile)
        fid = h5open(elevfile, "r")
        elevationmatrix = read(fid["polarization"]["elevation"])
        close(fid)
    else
        elevationmatrix = elevationangle(times, phasedir, stationinfo, pos)
    end

    if parangfile != "" && isfile(parangfile)
        fid = h5open(parangfile, "r")
        parallacticanglematrix = read(fid["polarization"]["parallacticangle"])
        close(fid)
    else
        parallacticanglematrix = parallacticangle(times, phasedir, stationinfo, pos)
    end

	# D-terms -- perform twice the feed angle rotation
	djonesmatrices = ones(eltype(data), 2, 2, numchan, size(stationinfo)[1]) # 2 x 2 x nchan x nant
    djonesr = zeros(Float32, numchan)
    djonesθ = zeros(Float32, numchan)
	polrotmatrices = ones(eltype(data), 2, 2, numchan, ntimes, size(stationinfo)[1])
    pjonesmatrices = ones(eltype(data), 2, 2, ntimes, size(stationinfo)[1])

    # compute D-terms
    if polframe != "sky"
        # compute in antenna frame
        @info("Applying instrumental polarization and NOT rotating back to sky frame (i.e. retain vis. in antenna frame) ...")
        
	    for ant in eachindex(stationinfo.station)
            #djonesmatrices[1, 2, :, ant] = genseries1d!(djonesmatrices[1, 2, :, ant], polmode, stationinfo.d_pol1_loc[ant], real(stationinfo.d_pol1_scale[ant]), Float32(0.0), numchan, rngcorrupt)
            #djonesmatrices[2, 1, :, ant] = genseries1d!(djonesmatrices[2, 1, :, ant], polmode, stationinfo.d_pol2_loc[ant], real(stationinfo.d_pol2_scale[ant]), Float32(0.0), numchan, rngcorrupt)

            # get amplitude and phase of the mean and std for pol1
            amplmean1 = Float32(abs(stationinfo.d_pol1_loc[ant]))
            amplstd1 = Float32(abs(stationinfo.d_pol1_scale[ant]))
            phasemean1 = Float32(angle(stationinfo.d_pol1_loc[ant]))
            phasestd1 = Float32(angle(stationinfo.d_pol1_scale[ant]))

            # generate 1-D series for amplitudes and phases independently
            if numchan > 1
                djonesr[:] = genseries1d!(djonesr, chanfreqvec, rngcorrupt, μ=amplmean1, σ=amplstd1, ρ=chanfreqvec[end]-chanfreqvec[begin])
            else
                djonesr[:] = genseries1d!(djonesr, polmode, amplmean1, amplstd1, Float32(0.0), numchan, rngcorrupt)
            end
            djonesθ[:] = genseries1d!(djonesθ, polmode, phasemean1, phasestd1, Float32(0.0), numchan, rngcorrupt)

            # convert back to Cartesian form and write to gjonesmatrix
            reals = djonesr .* cos.(djonesθ)
            imags = djonesr .* sin.(djonesθ)
            djonesmatrices[1, 2, :, ant] = [complex(r, i) for (r, i) in zip(reals, imags)]

            # get amplitude and phase of the mean and std for pol2
            amplmean2 = Float32(abs(stationinfo.d_pol2_loc[ant]))
            amplstd2 = Float32(abs(stationinfo.d_pol2_scale[ant]))
            phasemean2 = Float32(angle(stationinfo.d_pol2_loc[ant]))
            phasestd2 = Float32(angle(stationinfo.d_pol2_scale[ant]))

            # generate 1-D series for amplitudes and phases independently
            if numchan > 1
                djonesr[:] = genseries1d!(djonesr, chanfreqvec, rngcorrupt, μ=amplmean2, σ=amplstd2, ρ=chanfreqvec[end]-chanfreqvec[begin])
            else
                djonesr[:] = genseries1d!(djonesr, polmode, amplmean2, amplstd2, Float32(0.0), numchan, rngcorrupt)
            end
            djonesθ[:] = genseries1d!(djonesθ, polmode, phasemean2, phasestd2, Float32(0.0), numchan, rngcorrupt)

            # convert back to Cartesian form and write to gjonesmatrix
            reals = djonesr .* cos.(djonesθ)
            imags = djonesr .* sin.(djonesθ)
            djonesmatrices[2, 1, :, ant] = [complex(r, i) for (r, i) in zip(reals, imags)]

	        for t in 1:ntimes
    	        if uppercase(stationinfo.mount[ant]) == "ALT-AZ"
		            pjonesmatrices[1, 1, t, ant] = exp(-1*im)*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant])
		            pjonesmatrices[2, 2, t, ant] = exp(1*im)*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant])
		        elseif uppercase(stationinfo.mount[ant]) == "ALT-AZ+NASMYTH-L"
    		        pjonesmatrices[1, 1, t, ant] = exp(-1*im)*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]-elevationmatrix[t, ant])
		            pjonesmatrices[2, 2, t, ant] = exp(1*im)*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]-elevationmatrix[t, ant])
		        elseif uppercase(stationinfo.mount[ant]) == "ALT-AZ+NASMYTH-R"
		            pjonesmatrices[1, 1, t, ant] = exp(-1*im)*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]+elevationmatrix[t, ant])
		            pjonesmatrices[2, 2, t, ant] = exp(1*im)*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]+elevationmatrix[t, ant])
		        end
	        end
        end

	    # apply Dterms to data
        row = 1 # variable to index data array
        for scan in uniqscans
            # compute ideal ntimes per scan
            actualtscanvec = unique(getindex(times, findall(scanno.==scan)))
            actualtscanveclen = length(actualtscanvec)
            idealtscanvec = collect(first(actualtscanvec):exposure:last(actualtscanvec))
            idealtscanveclen = length(idealtscanvec)
    
            # loop over time/row and apply Dterms corresponding to each baseline
            findnearest(A,x) = argmin(abs.(A .- x)) # define function to find nearest neighbour
            for t in 1:actualtscanveclen
                idealtimeindex = findnearest(idealtscanvec, actualtscanvec[t])
                # read all baselines present in a given time
                ant1vec = getindex(antenna1, findall(times.==actualtscanvec[t]))
                ant2vec = getindex(antenna2, findall(times.==actualtscanvec[t]))
                for (ant1,ant2) in zip(ant1vec, ant2vec)
                    for chan in 1:numchan
                        data[:,:,chan,row] = djonesmatrices[:,:,chan,ant1+1]*pjonesmatrices[:,:,idealtimeindex,ant1+1]*data[:,:,chan,row]*adjoint(pjonesmatrices[:,:,idealtimeindex,ant2+1])*adjoint(djonesmatrices[:,:,chan,ant2+1])
                    end
                    row += 1 # increment data last index i.e. row number
                end
            end
        end
    else

        @info("Applying instrumental polarization and rotating back to sky frame ...")

	    for ant in eachindex(stationinfo.station)
            #djonesmatrices[1, 2, :, ant] = genseries1d!(djonesmatrices[1, 2, :, ant], polmode, stationinfo.d_pol1_loc[ant], real(stationinfo.d_pol1_scale[ant]), Float32(0.0), numchan, rngcorrupt)
            #djonesmatrices[2, 1, :, ant] = genseries1d!(djonesmatrices[2, 1, :, ant], polmode, stationinfo.d_pol2_loc[ant], real(stationinfo.d_pol2_scale[ant]), Float32(0.0), numchan, rngcorrupt)

            # get amplitude and phase of the mean and std for pol1
            amplmean1 = Float32(abs(stationinfo.d_pol1_loc[ant]))
            amplstd1 = Float32(abs(stationinfo.d_pol1_scale[ant]))
            phasemean1 = Float32(angle(stationinfo.d_pol1_loc[ant]))
            phasestd1 = Float32(angle(stationinfo.d_pol1_scale[ant]))

            # generate 1-D series for amplitudes and phases independently
            if numchan > 1
                djonesr[:] = genseries1d!(djonesr, chanfreqvec, rngcorrupt, μ=amplmean1, σ=amplstd1, ρ=chanfreqvec[end]-chanfreqvec[begin])
            else
                djonesr[:] = genseries1d!(djonesr, polmode, amplmean1, amplstd1, Float32(0.0), numchan, rngcorrupt)
            end
            djonesθ[:] = genseries1d!(djonesθ, polmode, phasemean1, phasestd1, Float32(0.0), numchan, rngcorrupt)

            # convert back to Cartesian form and write to gjonesmatrix
            reals = djonesr .* cos.(djonesθ)
            imags = djonesr .* sin.(djonesθ)
            djonesmatrices[1, 2, :, ant] = [complex(r, i) for (r, i) in zip(reals, imags)]

            # get amplitude and phase of the mean and std for pol2
            amplmean2 = Float32(abs(stationinfo.d_pol2_loc[ant]))
            amplstd2 = Float32(abs(stationinfo.d_pol2_scale[ant]))
            phasemean2 = Float32(angle(stationinfo.d_pol2_loc[ant]))
            phasestd2 = Float32(angle(stationinfo.d_pol2_scale[ant]))

            # generate 1-D series for amplitudes and phases independently
            if numchan > 1
                djonesr[:] = genseries1d!(djonesr, chanfreqvec, rngcorrupt, μ=amplmean2, σ=amplstd2, ρ=chanfreqvec[end]-chanfreqvec[begin])
            else
                djonesr[:] = genseries1d!(djonesr, polmode, amplmean2, amplstd2, Float32(0.0), numchan, rngcorrupt)
            end
            djonesθ[:] = genseries1d!(djonesθ, polmode, phasemean2, phasestd2, Float32(0.0), numchan, rngcorrupt)

            # convert back to Cartesian form and write to gjonesmatrix
            reals = djonesr .* cos.(djonesθ)
            imags = djonesr .* sin.(djonesθ)
            djonesmatrices[2, 1, :, ant] = [complex(r, i) for (r, i) in zip(reals, imags)]

	        for t in 1:ntimes
    	        for chan in 1:numchan
    	            if uppercase(stationinfo.mount[ant]) == "ALT-AZ"
		                polrotmatrices[1, 2, chan, t, ant] = djonesmatrices[1, 2, chan, ant] * exp(2*im*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]))
		                polrotmatrices[2, 1, chan, t, ant] = djonesmatrices[2, 1, chan, ant] * exp(-2*im*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]))
		            elseif uppercase(stationinfo.mount[ant]) == "ALT-AZ+NASMYTH-L"
    		            polrotmatrices[1, 2, chan, t, ant] = djonesmatrices[1, 2, chan, ant] * exp(2*im*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]-elevationmatrix[t, ant]))
		                polrotmatrices[2, 1, chan, t, ant] = djonesmatrices[2, 1, chan, ant] * exp(-2*im*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]-elevationmatrix[t, ant]))
		            elseif uppercase(stationinfo.mount[ant]) == "ALT-AZ+NASMYTH-R"
		                polrotmatrices[1, 2, chan, t, ant] = djonesmatrices[1, 2, chan, ant] * exp(2*im*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]+elevationmatrix[t, ant]))
		                polrotmatrices[2, 1, chan, t, ant] = djonesmatrices[2, 1, chan, ant] * exp(-2*im*(deg2rad(stationinfo.feedangle_deg[ant])+parallacticanglematrix[t, ant]+elevationmatrix[t, ant]))
		            end
    	        end
	        end
        end

	    # apply Dterms to data TODO rewrite the following loop
        row = 1 # variable to index data array
        for scan in uniqscans
            # compute ideal ntimes per scan
            actualtscanvec = unique(getindex(times, findall(scanno.==scan)))
            actualtscanveclen = length(actualtscanvec)
            idealtscanvec = collect(first(actualtscanvec):exposure:last(actualtscanvec))
            idealtscanveclen = length(idealtscanvec)
    
            # loop over time/row and apply Dterms corresponding to each baseline
            findnearest(A,x) = argmin(abs.(A .- x)) # define function to find nearest neighbour
            for t in 1:actualtscanveclen
                idealtimeindex = findnearest(idealtscanvec, actualtscanvec[t])
                # read all baselines present in a given time
                ant1vec = getindex(antenna1, findall(times.==actualtscanvec[t]))
                ant2vec = getindex(antenna2, findall(times.==actualtscanvec[t]))
                for (ant1,ant2) in zip(ant1vec, ant2vec)
                    for chan in 1:numchan
                        data[:,:,chan,row] = polrotmatrices[:,:,chan,idealtimeindex,ant1+1]*data[:,:,chan,row]*adjoint(polrotmatrices[:,:,chan,idealtimeindex,ant2+1])
                    end
                    row += 1 # increment data last index i.e. row number
                end
            end
        end
    end

    # write polarization matrices to HDF5 file
    if !isempty(h5file)
        fid = h5open(h5file, "cw")
        g = create_group(fid, "polarization")
        HDF5.attributes(g)["desc"] = "Numerical values of instrumental polarization matrices applied to data (Dterms and fullpolproduct)"
        HDF5.attributes(g)["dims"] = "2 x 2 x nchannels x nant" #for each scan, a 4d array of 2 x 2 x nchan x nant is stored

        if !(haskey(g, "elevation"))
            g["elevation"] = elevationmatrix
        end

        if !(haskey(g, "parallacticangle"))
            g["parallacticangle"] = parallacticanglematrix
        end

        g["djonesmatrices"] = djonesmatrices
        g["polrotmatrices"] = polrotmatrices
        g["pjonesmatrices"] = pjonesmatrices
        HDF5.attributes(g)["datatype"] = string(typeof(read(g[keys(g)[1]])))
        close(fid)
    end

    @info("Compute and apply polarization models 🙆")
    
end

"""
    instrumentalpolarization!(ms::MeasurementSet, stationinfo::DataFrame, obsconfig::Dict; h5file::String="",
    elevfile::String="", parangfile::String="")

Alias for use in pipelines.
"""
function instrumentalpolarization!(ms::MeasurementSet, stationinfo::DataFrame, obsconfig::Dict; h5file::String="",
    elevfile::String="", parangfile::String="")
    instrumentalpolarization!(ms.data, ms.scanno, ms.times, stationinfo, ms.phasedir, ms.pos, ms.chanfreqvec,
    obsconfig["instrumentalpolarization"]["visibilityframe"], obsconfig["instrumentalpolarization"]["mode"], ms.antenna1,
    ms.antenna2, ms.exposure, obsconfig["corruptseed"], h5file=h5file, elevfile=elevfile, parangfile=parangfile)
end