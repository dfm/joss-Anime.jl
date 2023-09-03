# utilities to handle alist files. Modelled after the EAT library -- https://github.com/sao-eht/eat/blob/master/eat/io/hops.py

export readalistv5, readalistv6

"""
    readalistv5(alistfile::String)

Read in an alist v5 file generated by HOPS. 
"""
function readalistv5(alistfile::String)

    # set header names
    columns = "version,root_id,two,extent_no,duration,length,offset,expt_no,scan_id,procdate,year,timetag,scan_offset,source,baseline,quality,freq_code,polarization,lags,amp,snr,resid_phas,phase_snr,datatype,sbdelay,mbdelay,ambiguity,delay_rate,ref_elev,rem_elev,ref_az,rem_az,u,v,esdesp,epoch,ref_freq,total_phas,total_rate,total_mbdelay,total_sbresid,srch_cotime,noloss_cotime"
    header = [string(sub) for sub in split(columns, ",")]

    df = CSV.read(alistfile, DataFrame; header=header, comment="*", delim=" ", ignorerepeated=true)

    return df
end

"""
    readalistv6(alistfile::String)

Read in an alist v6 file generated by HOPS. 
"""
function readalistv6(alistfile::String)

    # set header names
    columns = "version,root_id,two,extent_no,duration,length,offset,expt_no,scan_id,procdate,year,timetag,scan_offset,source,baseline,quality,freq_code,polarization,lags,amp,snr,resid_phas,phase_snr,datatype,sbdelay,mbdelay,ambiguity,delay_rate,ref_elev,rem_elev,ref_az,rem_az,u,v,esdesp,epoch,ref_freq,total_phas,total_rate,total_mbdelay,total_sbresid,srch_cotime,noloss_cotime,ra_hrs,dec_deg,resid_delay"
    header = [string(sub) for sub in split(columns, ",")]

    df = CSV.read(alistfile, DataFrame; header=header, comment="*", delim=" ", ignorerepeated=true)

    return df
end