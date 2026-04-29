%****
% Program to take NetCDF files from OSU and reformat to IOOS for SeaGlider
% code written by flbahr@mbari.org
%****
%
run('/home/matlab/startup.m');
run('/home/matlab/pathdef.m');
%
% The following just loads an counter, an id, a path to the data, and
% glider file name.
%
[i,id,gliderpath,gliderfile]=read_seaglider_cfg;  %#ok<ASGLU>
%
% set up paths to data
%
glidersn=id{1};
pathspray=gliderpath{1};
%pathspray='/home/matlab/seaglider/';  %#ok<NASGU>
%glidersn=157;
%if strcmp(glidersn,'157')
%    gliderwmo=4801906; 
%glidersn=id{1}; 
% glidersn=130;
%    ggnn=['UW',glidersn];
%    ognn=['SG',glidersn];
%else
    % code for SG266
    gliderwmo='8901088';
    % code for SG686
    %gliderwmo='8901047';
    % code for SG685
    %gliderwmo='4803976';
    ggnn=['OSU',glidersn];
    ognn=['SG',glidersn];

    % code below is for SG646
    %gliderwmo='4802955';
    %ggnn=['UW',glidersn];
    %ognn=['SG',glidersn];

    % code below is for SG130
    %gliderwmo='4801907';
    %ggnn=['UW',glidersn];
    %ognn=['SG',glidersn];
%end
%
% Directory name for IOOS submission
% S/N-YYYYmmDDTHHMM where the time is the time of deployment.
%
%h='OSU686-20240412T0000';
h='OSU266-20260314T0000';
%h='OSU686-20251113T0000';
%h='OSU266-20250307T0000';
%h='OSU266-20241022T0000';
%h='OSU685-20231023T0000';
%h='OSU686-20230829T0000';
%h='UW685-20230125T0000';
%h='UW646-20220907T0000';
%h='UW646-20210816T0000';
%h='UW157-20200917T0000';
%h='UW130-20200615T0000';
%h='UW157-20190916T0000';
%h='UW646-20190409T0000';
%h='UW130-20181107T0000';
%h='UW157-20180417T1832';
%h='UW130-20170605T1834';
%h='UW157-20161021T1807';
%h='UW130-20160523T1828';
% h='UW157-20150917T1833';
% h='UW130-20150309T2005';
% need to get a list of file names
%x=dir('/home/matlab/seaglider/p13*.nc');
%
eval(['x=dir(''',gliderpath{1},'p',glidersn,'*.nc'');']);
m=length(x);
offset=datenum(1970,1,1,0,0,0);
iprofile=1;
%
% need some code to see what files are there and wether we need to load the
% profile number or not.
%
% Each profile needs to be output as an individual file.
% Note up and down casts should be in seperate files.
for i=1:m
    %if i ~= 244,
    disp(i)
    filename=x(i).name;
    filesize=x(i).bytes;
    if filesize > 0
        % Let's see if the file has been converted or not...
        % to avoid lots of work let's get the existing converted seaglider files
        % unfortuneately can not move this out of the loop, as we only find
        % the last file and if we have multiple files after that we will
        % keep adding the same profileid to all of those files and not
        % actually updating. Fix profileid by using dive number...
         glidersnstr=[pathspray,'OSU',id{1}];
         %glidersnstr=['/home/matlab/seaglider/UW',num2str(glidersn)];
         eval(['y=dir(''',glidersnstr,'*.nc'');']);
         ly=length(y);
         if ly > 0
             % look for files already computed and only do the new ones.
            [flag,profileid]=find_previous(y,[gliderpath{1},filename]);    %#ok<ASGLU>
            if flag==1
                continue; % jump us to the next increment in the i-loop
            else
                % using dive number we don't care about profile number
                % since we can just compute it from that number.
                ips=filename(5:8);
                ipn=str2double(ips);
                iprofile=ipn*2-1;
%                iprofile=profileid+1;
            end
        end
        %   
        ncid1=netcdf.open([gliderpath{1},filename],'NOWRITE');
        % Now we need to create new file name for processed file to write to
        % I don't appear to use this code comment out for now
        %[ndims,nvars,ngatts,unlimitid]=netcdf.inq(ncid1); 
        %for j=1:nvars,
        %    [varname{j},xtype(j),dims(j,:),natts(j,:)]=netcdf.inqVar(ncid1,j-1); %#ok<SAGROW>
        %end
        % search for the variable time
        % unfortunately we need to split a dive into pieces (down and up)
        varid=netcdf.inqVarID(ncid1,'ctd_time');
        %varid=netcdf.inqVarID(ncid1,'time');
        time=netcdf.getVar(ncid1,varid);
        % time is seconds since 1970,1,1
        ztime=time/24/60/60+offset;
        % function to check for file or not....
        %
        % Need code here to split values and loop through 2 times (down then
        % up).
        did=netcdf.inqVarID(ncid1,'ctd_depth');
        depth=netcdf.getVar(ncid1,did);
        %did=netcdf.inqVarID(ncid1,'depth');
        %depth=netcdf.getVar(ncid1,did);
        latid=netcdf.inqVarID(ncid1,'latitude');
        latv=netcdf.getVar(ncid1,latid);
        lonid=netcdf.inqVarID(ncid1,'longitude');
        lonv=netcdf.getVar(ncid1,lonid);
        pressid=netcdf.inqVarID(ncid1,'ctd_pressure');
        press=netcdf.getVar(ncid1,pressid);
        %pressid=netcdf.inqVarID(ncid1,'pressure');
        %press=netcdf.getVar(ncid1,pressid);
        tempid=netcdf.inqVarID(ncid1,'temperature');
        ttemp=netcdf.getVar(ncid1,tempid);
        tempid=netcdf.inqVarID(ncid1,'temperature_qc');
        temp_qc=netcdf.getVar(ncid1,tempid);
        saltid=netcdf.inqVarID(ncid1,'salinity');
        tsalt=netcdf.getVar(ncid1,saltid);
        saltid=netcdf.inqVarID(ncid1,'salinity_qc');
        salt_qc=netcdf.getVar(ncid1,saltid);
        condid=netcdf.inqVarID(ncid1,'conductivity');
        tcond=netcdf.getVar(ncid1,condid);
        condid=netcdf.inqVarID(ncid1,'conductivity_qc');
        cond_qc=netcdf.getVar(ncid1,condid);
        denid=netcdf.inqVarID(ncid1,'density');
        density=netcdf.getVar(ncid1,denid);
        % 130?
	if strcmp(glidersn,'266')
        %if strcmp(glidersn,'130')
	%if strcmp(glidersn,'686')
	%if strcmp(glidersn,'685')
       	%if strcmp(glidersn,'646')
       	%if strcmp(glidersn,'157')

	% for 266
	   flid=netcdf.inqVarID(ncid1,'wlbbfl2_sig695nm_adjusted');
        %    flid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_FL1sig');
        %    %ftimeid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_time');
	    ftimeid=netcdf.inqVarID(ncid1,'wlbbfl2_results_time');
            %ftimeid=netcdf.inqVarID(ncid1,'time');
            ftime=netcdf.getVar(ncid1,ftimeid);
            ftime=ftime/24/60/60+offset;
            %flid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_sig695');
        %    tfluo=netcdf.getVar(ncid1,flid);
        %    tfluo=interp1(ftime,tfluo,ztime);
            %
        % 157
        %flid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_sig695');
        %else
%            flid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_sig695nm');
%       %     flid=netcdf.inqVarID(ncid1,'eng_wlbb2flvmt_Chlsig');
            tfluo=netcdf.getVar(ncid1,flid);
	    tfluo=interp1(ftime,tfluo,ztime);
        end
        %
        % 130
        %if strcmp(glidersn,'130')
	% for 266
	if strcmp(glidersn,'266')
	%if strcmp(glidersn,'686')
	%if strcmp(glidersn,'685')
        %if strcmp(glidersn,'646')
        %if strcmp(glidersn,'157')
	    % for 266
	     bbid=netcdf.inqVarID(ncid1,'wlbbfl2_sig700nm_adjusted');
	     cdomid=netcdf.inqVarID(ncid1,'wlbbfl2_sig460nm_adjusted');
            %bbid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_BB1sig');
            %cdomid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_FL2sig');
         %bbid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_sig650');
         %cdomid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_sig460');
         
%          bbid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_sig700nm');
        % 157?
%        else
%            bbid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_sig700nm');
%            cdomid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_sig460nm');
%%         bbid=netcdf.inqVarID(ncid1,'eng_wlbb2flvmt_wl600sig');
%%         cdomid=netcdf.inqVarID(ncid1,'eng_wlbb2flvmt_Cdomsig');
        end
%         backscatter=bb; %#ok<NASGU>
%         cdomid=netcdf.inqVarID(ncid1,'eng_wlbbfl2_sig460nm');
         bb=netcdf.getVar(ncid1,bbid);
         cdom=netcdf.getVar(ncid1,cdomid);
         bb=interp1(ftime,bb,ztime);
         cdom=interp1(ftime,cdom,ztime);
	 % for 266 the adjusted data already has this applied
	 % cwo_chl and sfc_chl are not needed
	 % cwo_chl=49; sfc_chl=0.121;
	 % values for glider 686
	%cwo_chl=49;
	%sfc_chl=0.0121;
	% values for glider 685
	%cwo_chl=44;
	%sfc_chl=0.0122;
	%values for glider 646
	%cwo_chl=44;
	%sfc_chl=0.0122;
	 %values for glider 130
	 %cwo_chl=56;
	 %sfc_chl=0.0120;
	% values for glider 157
        %cwo_chl=54;
        %sfc_chl=0.0121;
	% for 266
	tfluo=tfluo;
	% tfluo=(tfluo-cwo_chl).*sfc_chl;
%         tfluo=tfluo*sfc_chl+cwo_chl; % convert to units of mg/l
	% for 266 no need for this
	% cwo_cdom and sfc_cdom not needed
	% cwo_cdom=49; sfc_cdom=0.0909;
	% values for glider 686
	%cwo_cdom=50;
	%sfc_cdom=0.0907;
	% values for glider 685
	% cwo_cdom=35;
	% sfc_cdom=0.0899;
	% values for glider 646
	 % cwo_cdom=35;
	 % sfc_cdom=0.0899;
	% values for glider 130
	%  cwo_cdom=62;
	%  sfc_cdom=0.1429;
	% values for glider 157
        %cwo_cdom=42;
        %sfc_cdom=0.1954;
	% for 266
	cdom=cdom;
	% cdom=(cdom-cwo_cdom).*sfc_cdom;
%         cdom=cdom.*sfc_cdom+cwo_cdom;
	% for 266 no need for these number
	% cwo_bb and sfc_bb
	% cwo_bb=48; sfc_bb=3.071e-06;
	% values for glider 686
	%cwo_bb=48;
	%sfc_bb=3.475e-06;
	% values for glider 685
	% cwo_bb=44;
	% sfc_bb=3.075e-06;
	% values for glider 646
	%cwo_bb=44;
	%sfc_bb=3.074e-06;
	% values for glider 130
	%  cwo_bb=50;
	%  sfc_bb=3.465e-6;
	% values for glider 157
        %cwo_bb=39;
        %sfc_bb=5.607e-06;
        backscatter=bb;
 	% for 266
	 backscatter=backscatter;
	% backscatter=(bb-cwo_bb).*sfc_bb;
%         backscatter=bb.*sfc_bb+cwo_bb;
%        oxyid=netcdf.inqVarID(ncid1,'sbe43_dissolved_oxygen');
%        oxyid=netcdf.inqVarID(ncid1,'aanderaa4330_dissolved_oxygen');
        oxyid=netcdf.inqVarID(ncid1,'aanderaa4831_dissolved_oxygen');
        oxyg=netcdf.getVar(ncid1,oxyid);
        oxytid=netcdf.inqVarID(ncid1,'aanderaa4831_results_time');
        oxytime=netcdf.getVar(ncid1,oxytid);
        oxytime=oxytime/24/60/60+offset;
        oxyg=interp1(oxytime,oxyg,ztime);
        oxyqcid=netcdf.inqVarID(ncid1,'aanderaa4831_dissolved_oxygen_qc');
%        oxyqcid=netcdf.inqVarID(ncid1,'aanderaa4330_dissolved_oxygen_qc');
%        oxyqcid=netcdf.inqVarID(ncid1,'sbe43_dissolved_oxygen_qc');
        oxyqc=netcdf.getVar(ncid1,oxyqcid);
        if ischar(oxyqc)==1
            oxyqc=str2num(oxyqc); %#ok<ST2NM>
        end
        oxyqc=interp1(oxytime,oxyqc,ztime);
        latuvid=netcdf.inqVarID(ncid1,'avg_latitude');
        lat_uv=netcdf.getVar(ncid1,latuvid);
        lonid=netcdf.inqVarID(ncid1,'longitude');
        lons=netcdf.getVar(ncid1,lonid);
        ll=isnan(lons)==1; %#ok<COMPNOP>
        lons(ll)=[];
        lon_uv=mean(lons);
        time_uv=(time(1)+time(end))/2;
        ucurrid=netcdf.inqVarID(ncid1,'depth_avg_curr_east');
        ucurr=netcdf.getVar(ncid1,ucurrid);
        uqcid=netcdf.inqVarID(ncid1,'depth_avg_curr_qc');
        u_qc=netcdf.getVar(ncid1,uqcid);
        vcurrid=netcdf.inqVarID(ncid1,'depth_avg_curr_north');
        vcurr=netcdf.getVar(ncid1,vcurrid);
        vqcid=netcdf.inqVarID(ncid1,'depth_avg_curr_qc');
        v_qc=netcdf.getVar(ncid1,vqcid);
    % Now to split into down and up cast/profiles
    % and to rename variables so they work the way we want them to
        [jnk,ind]=max(depth);  %#ok<ASGLU>
        otime=time; clear time;
        oztime=ztime; clear ztime;
        odepth=depth; clear depth;
        olatv=latv; clear latv;
        olonv=lonv; clear lonv;
        opress=press; clear press;
        ottemp=ttemp; clear ttemp;
        otsalt=tsalt; clear tsalt;
        otemp_qc=temp_qc; clear temp_qc;
        osalt_qc=salt_qc; clear salt_qc;
        otcond=tcond; clear tcond;
        ocond_qc=cond_qc; clear cond_qc;
        odensity=density; clear density;
        otfluo=tfluo; clear tfluo;
        oback=backscatter; clear backscatter;
        ocdom=cdom; clear cdom;
        ooxyg=oxyg; clear oxyg;
        ooxyqc=oxyqc; clear oxyqc;
        olat_uv=lat_uv; clear lat_uv;
        olon_uv=lon_uv; clear lon_uv;
        otime_uv=time_uv; clear time_uv;
        oucurr=ucurr; clear ucurr;
        ou_qc=u_qc; clear u_qc;
        ovcurr=vcurr; clear vcurr;
        ov_qc=v_qc; clear v_qc;
        for k=1:2
            if k==1
                time=otime(1:ind);
                ztime=oztime(1:ind);
                depth=odepth(1:ind);
                latv=olatv(1:ind);
                lonv=olonv(1:ind);
                press=opress(1:ind);
                ttemp=ottemp(1:ind);
                tsalt=otsalt(1:ind);
                temp_qc=otemp_qc(1:ind);
                salt_qc=osalt_qc(1:ind);
                tcond=otcond(1:ind);
                cond_qc=ocond_qc(1:ind);
                density=odensity(1:ind);
                tfluo=otfluo(1:ind);
                backscatter=oback(1:ind);
                cdom=ocdom(1:ind);
                oxyg=ooxyg(1:ind);
                oxyqc=ooxyqc(1:ind);
                lat_uv=olat_uv;
                lon_uv=olon_uv;
                ptime=(time(1)+time(end))./2;
                %time_uv=(time(1)+time(end))./2;
                time_uv=otime_uv;
                ucurr=oucurr;
                u_qc=ou_qc;
                vcurr=ovcurr;
                v_qc=ov_qc;
            else
                time=otime(ind+1:end);
                ztime=oztime(ind+1:end);
                depth=odepth(ind+1:end);
                latv=olatv(ind+1:end);
                lonv=olonv(ind+1:end);
                press=opress(ind+1:end);
                ttemp=ottemp(ind+1:end);
                tsalt=otsalt(ind+1:end);
                temp_qc=otemp_qc(ind+1:end);
                salt_qc=osalt_qc(ind+1:end);
                tcond=otcond(ind+1:end);
                cond_qc=ocond_qc(ind+1:end);
                density=odensity(ind+1:end);
                tfluo=otfluo(ind+1:end);
                backscatter=oback(ind+1:end);
                cdom=ocdom(ind+1:end);
                oxyg=ooxyg(ind+1:end);
                oxyqc=ooxyqc(ind+1:end);
                lat_uv=mean(latv);
                lon_uv=mean(lonv);
%                lat_uv=-999.0;
%                lon_uv=-999.0;
                if isempty(time)==0
                    ptime=(time(1)+time(end))./2;
                    downflag=1; %#ok<NASGU>
                else
                    ptime=[];
                    downflag=0; %#ok<NASGU>
                end
                time_uv=ptime;
                ucurr=-999;
                u_qc=-127;
                vcurr=-999.;
                v_qc=-127;
            end
            ll=isnan(ttemp)==1; %#ok<COMPNOP>
            ttemp(ll)=-1e34;
            ll=isnan(tsalt)==1; %#ok<COMPNOP>
            tsalt(ll)=-1e34;
            ll=isnan(tcond)==1; %#ok<COMPNOP>
            tcond(ll)=-1e34;
            ll=isnan(density)==1; %#ok<COMPNOP>
            density(ll)=-1e34;
            ll=isnan(tfluo)==1; %#ok<COMPNOP>
            tfluo(ll)=-1e34;
            ll=isnan(cdom)==1; %#ok<COMPNOP>
            cdom(ll)=-1e34;
            ll=isnan(backscatter)==1;   %#ok<COMPNOP>
            backscatter(ll)=-1e34;
            ll=isnan(oxyg)==1; %#ok<COMPNOP>
            oxyg(ll)=-1e34;
        %boolind=strcmp('time',varname);
        %tind=find(boolind);
    %if ~isempty(ptime)
    if ~isempty(ztime)
	filename2=[pathspray,'OSU266_',datestr(ztime(1),'yyyymmddTHHMMSS'),'_rt0.nc'];
        %filename2=[pathspray,'UW157_',datestr(ztime(1),'yyyymmddTHHMMSS'),'_rt0.nc'];
	%filename2=[pathspray,'OSU686_',datestr(ztime(1),'yyyymmddTHHMMSS'),'_rt0.nc'];
	%filename2=[pathspray,'OSU685_',datestr(ztime(1),'yyyymmddTHHMMSS'),'_rt0.nc'];
       %filename2=[pathspray,'UW646_',datestr(ztime(1),'yyyymmddTHHMMSS'),'_rt0.nc'];
        %filename2=['UW130_',datestr(ztime(1),'yyyymmddTHHMMSS'),'_rt0.nc'];
        %ncid2=netcdf.open(filename2,'WRITE');
        nc_create_empty(filename2);
%        nc_create_empty(['/home/matlab/seaglider/',filename2]);
        nc_add_dimension(filename2,'time',0);
        nc_add_dimension(filename2,'traj_strlen',21)
        %nc_add_dimension(filename2,'time_uv',1);
        %nc_add_dimension(ofname,'time_uv',casts);
        %nc_add_dimension(filename2,'trajectory',1);
        nc_attput(filename2,nc_global,'Conventions','CF-1.6,ACDD-1.3');
        nc_attput(filename2,nc_global,'Metadata_Conventions','CF-1.6,Unidata Dataset Discovery v1.0');
        nc_attput(filename2,nc_global,'acknowledgment','Integrated Ocean Observing System (IOOS)NANOOS NOAA, Grant NA1NOOSO20036,Integrated Ocean Observing System(IOOS) CeNCOOS NOAA,Grant NA11NOs0120032');
	nc_attput(filename2,nc_global,'comment','Data has not been reviewed and is provided AS-IS');
        %nc_attput(filename2,nc_global,'comment',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'disclaimer'));
        nc_attput(filename2,nc_global,'cdm_data_type','Trajectory');
        nc_attput(filename2,nc_global,'contributor_name','Jack Barth, R. Kipp Shearman');
        nc_attput(filename2,nc_global,'contributor_role','Principal investigator, Principal investigator');
        nc_attput(filename2,nc_global,'creator_email','barth@coas.oregonstate.edu');
        nc_attput(filename2,nc_global,'creator_name','Jack Barth');
        nc_attput(filename2,nc_global,'creator_url','gliderfs2.coas.oregonstate.edu/gliderweb');
        nc_attput(filename2,nc_global,'date_created',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'date_created'));
        nc_attput(filename2,nc_global,'date_issued',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'date_modified'));
        nc_attput(filename2,nc_global,'date_modified',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'date_modified'));
        nc_attput(filename2,nc_global,'featureType','trajectory');
        nc_attput(filename2,nc_global,'format_version','IOOS_Glider_NetCDF_v2.0.nc');
        nc_attput(filename2,nc_global,'ncei_template_version','NCEI_NetCDF_Trajectory_Template_v2.0');
        %nc_attput(filename2,nc_global,'geospatial_lat_max',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'geospatial_lat_max'));
        %nc_attput(filename2,nc_global,'geospatial_lat_min',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'geospatial_lat_min'));
        %nc_attput(filename2,nc_global,'geospatial_lat_resolution','seconds');
        %nc_attput(filename2,nc_global,'geospatial_lat_units','degrees_north');
        %nc_attput(filename2,nc_global,'geospatial_lon_max',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'geospatial_lon_max'));
        %nc_attput(filename2,nc_global,'geospatial_lon_min',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'geospatial_lon_min'));
        %nc_attput(filename2,nc_global,'geospatial_lon_resolution','seconds');
        %nc_attput(filename2,nc_global,'geospatial_lon_units','degrees_east');
        %nc_attput(filename2,nc_global,'geospatial_vertical_max',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'geospatial_vertical_max'));
        %nc_attput(filename2,nc_global,'geospatial_vertical_min',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'geospatial_vertical_min'));
        %nc_attput(filename2,nc_global,'geospatial_vertical_positive','down');
        %nc_attput(filename2,nc_global,'geospatial_vertical_resolution','centimeter');
        %nc_attput(filename2,nc_global,'geospatial_vertical_units','meter');
        nc_attput(filename2,nc_global,'gts_ingest','true');
        nc_attput(filename2,nc_global,'history',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'history'));
        nc_attput(filename2,nc_global,'id',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'id'));
        nc_attput(filename2,nc_global,'institution','Oregon State University');
%        nc_attput(filename2,nc_global,'institution',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'institution'));
        %nc_attput(filename2,nc_global,'keywords','Water Temperature, Conductivity, Salinity, Density, Potential Density, Potential Temperature,Oxygen,Chlorophyll Fluorescence, CDOM Fluorescence Back Scatter');
	nc_attput(filename2,nc_global,'keywords',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'keywords'));
        %nc_attput(filename2,nc_global,'Keywords_vocabulary','NASA/GCMD Earth Science Keywords VErsion 6.0.0.0');
	nc_attput(filename2,nc_global,'keywords_vocabulary',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'keywords_vocabulary'));
	nc_attput(filename2,nc_global,'license','These data may be redistributed and used without restriction');
        %nc_attput(filename2,nc_global,'license',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'license'));
        nc_attput(filename2,nc_global,'metadata_link','https://www.nodc.noaa.gov/data/formats/netcdf/v2.0/');
        nc_attput(filename2,nc_global,'nameing_authority','edu.washington.apl');
	%nc_attput(filename2,nc_global,'naming_authority',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'naming_authority'));
        nc_attput(filename2,nc_global,'platform_type','Seaglider');
	nc_attput(filename2,nc_global,'processing_level',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'processing_level'));
        nc_attput(filename2,nc_global,'project',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'project'));
        %nc_attput(filename2,nc_global,'publisher_email','barth@coas.oregonstate.edu');
        nc_attput(filename2,nc_global,'publisher_email','cencoos_communications@mbari.org');
       
%        nc_attput(filename2,nc_global,'publisher_email',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'publisher_email'));
%        nc_attput(filename2,nc_global,'publisher_name','Oregon State University, College of Ocean and Atmospheric Sciences');
        nc_attput(filename2,nc_global,'publisher_name','Central and Northern California Ocean Observing System (CeNCOOS)');
%        nc_attput(filename2,nc_global,'publisher_name',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'publisher_name'));
        %nc_attput(filename2,nc_global,'publisher_url','gliderfs.coas.oregonstate.edu/gliderweb');
        nc_attput(filename2,nc_global,'publisher_url','www.cencoos.org');
%        nc_attput(filename2,nc_global,'publisher_url',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'publisher_url'));
        nc_attput(filename2,nc_global,'references','http://data.nodc.noaa.gov/accession/0092291');
%        nc_attput(filename2,nc_global,'references',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'references'));
	nc_attput(filename2,nc_global,'sea_name','North Pacific Ocean');
       % nc_attput(filename2,nc_global,'sea_name',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'sea_name'));
        gsource=netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'source');
        gsource=strrep(gsource,ognn,ggnn);
%	gsource=strrep(gsource,'SG157','UW157');
        nc_attput(filename2,nc_global,'source',gsource);
%        nc_attput(filename2,nc_global,'source',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'source'));
        nc_attput(filename2,nc_global,'standard_name_vocabulary',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'standard_name_vocabulary'));
        gsum=netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'summary');
        gsum=strrep(gsum,ognn,ggnn);
	gsum='Seaglider OSU266 Trinidad Head IOOS Line, California.  Profiling glider travelling along latitude 41 N from -124 to -130 approximately.  The glider measures Temperature, Salinity, Chlorophyll,CDOM, Dissolved Oxygen, and Optical backscatter at 600nm.  The goal is both to monitor local conditions, to monitor the california current, to provide climatology of said current, and to provide subsurface data for ingest into numberical models.';

	%gsum='Seaglider OSU686 Trinidad Head IOOS Line, California.  Profiling glider travelling along latitude 41 N from -124 to -130 approximately.  The glider measures Temperature, Salinity, Chlorophyll,CDOM, Dissolved Oxygen, and Optical backscatter at 600nm.  The goal is both to monitor local conditions, to monitor the california current, to provide climatology of said current, and to provide subsurface data for ingest into numberical models.';
%	gsum=strrep(gsum,'SG157','UW157');
        nc_attput(filename2,nc_global,'summary',gsum);
%        nc_attput(filename2,nc_global,'summary',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'summary'));
        gtitle=netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'title');
        gtitle=strrep(gtitle,ognn,ggnn);
%	gtitle=strrep(gtitle,'SG157','UW157');
        nc_attput(filename2,nc_global,'title',gtitle);
%        nc_attput(filename2,nc_global,'title',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'title'));
        nc_attput(filename2,nc_global,'wmo_id',gliderwmo); % need to get assigned.
        nc_attput(filename2,nc_global,'ioos_regional_association','CeNCOOS,NANOOS');
        %nc_attput(filename2,nc_global,'time_coverage_end',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'time_coverage_end'));
        %nc_attput(filename2,nc_global,'time_coverage_resolution',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'time_coverage_resolution'));
        %nc_attput(filename2,nc_global,'time_coverage_start',netcdf.getAtt(ncid1,netcdf.getConstant('NC_GLOBAL'),'time_coverage_start'));
        % start to make record variable
        clear varstruct
        varstruct.Name='time';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        %nc_attput(filename2,'time','axis','T');
        nc_attput(filename2,'time','_FillValue',-999.0);
        nc_attput(filename2,'time','ancillary_variables','time_qc');
        nc_attput(filename2,'time','calendar','gregorian');
        nc_attput(filename2,'time','standard_name','time');
        nc_attput(filename2,'time','long_name','Time');
        nc_attput(filename2,'time','units','seconds since 1970-01-01T00:00:00Z');
        %nc_attput(filename2,'time','valid_min',time(1));
        %nc_attput(filename2,'time','valid_max',time(end));
        %nc_attput(filename2,'time','uncertainty',0.003);
        nc_attput(filename2,'time','observation_type','measured');
        %nc_attput(filename2,'time','sensor_name',' ');
        nc_varput(filename2,'time',time);

        time_qc=ones(size(time));
        ll=time==-1e34;
        time_qc(ll)=-127;
        clear varstruct;
        varstruct.Name='time_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'time_qc',time_qc);
        nc_attput(filename2,'time_qc','long_name','Time Quality Flag');
        nc_attput(filename2,'time_qc','standard_name','time status flag');
        nc_attput(filename2,'time_qc','_FillValue',-127);
        nc_attput(filename2,'time_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'time_qc','valid_min',0);
        nc_attput(filename2,'time_qc','valid_max',9);
        nc_attput(filename2,'time_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_potentially_corretable bad_data value_changed interpolated_value');

        clear varstruct;
        %h='UW130-20150309T2005';
        varstruct.Name='trajectory';
        varstruct.Nctype='char';
        varstruct.Dimension={'traj_strlen'};
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'trajectory','cf_role','trajectory_id');
        nc_attput(filename2,'trajectory','_FillValue','');
        nc_attput(filename2,'trajectory','comment','A trajectory is a single deployment of a glider and may span multiple data files');
        nc_attput(filename2,'trajectory','long_name','Trajectory/Deployment/ Name');
       % keyboard;
        nc_varput(filename2,'trajectory',h');  

        % don't have time_uv need to figure this value out....

    %  % the is some question as to what this number should be looks like it should just be 1   
    %
    % Technically by IOOS naming convention there are 2 dives per 1 seaglider
    % dive.  So the profile ID should not be the dive number but some multiple
    % of it based upon which dive number and is it the up or down cast.
    % May need to compute this.
    %

        clear varstruct
        varstruct.Name='depth';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'depth','long_name','Depth'); % yes
        nc_attput(filename2,'depth','standard_name','depth'); % yes
        nc_attput(filename2,'depth','units','m'); %yes
        nc_attput(filename2,'depth','positive','down'); %yes
        nc_attput(filename2,'depth','_FillValue',-999.0); % yes
        nc_attput(filename2,'depth','accuracy','0.1'); % yes
        nc_attput(filename2,'depth','comment','depth of glider'); % yes
        nc_attput(filename2,'depth','valid_min',0.0); % yes
        nc_attput(filename2,'depth','valid_max',12000.0); %yes
        nc_attput(filename2,'depth','precision','0.1'); %yes
        nc_attput(filename2,'depth','resolution','0.1'); %yes
        %nc_attput(filename2,'depth','uncertainty',0.1);
	%nc_attput(filename2,'depth','gts_ingest','true');
        nc_attput(filename2,'depth','reference_datum','sea_surface'); %yes
        nc_attput(filename2,'depth','observation_type','calculated'); %yes
        nc_attput(filename2,'depth','axis','Z');
        nc_attput(filename2,'depth','platform','platform'); %yes
        nc_attput(filename2,'depth','instrument','instrument_ctd'); % yes
        %nc_attput(filename2,'depth','sensor_name',' ');
        nc_attput(filename2,'depth','ancillary_variables','depth_qc');% yes
        nc_varput(filename2,'depth',depth);
    %	nc_varput(filename2,'depth',netcdf.getVar(ncid1,did));
    %
        depth_qc=zeros(size(depth));

        clear varstruct
        varstruct.Name='depth_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'depth_qc','standard_name','depth status_flag');
        nc_attput(filename2,'depth_qc','long_name','Depth Quality Flag');
        nc_attput(filename2,'depth_qc','_FillValue',-127);
        nc_attput(filename2,'depth_qc','valid_min',0);
        nc_attput(filename2,'depth_qc','valid_max',9);
        nc_attput(filename2,'depth_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'depth_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed interpolated_value missing_value');
        nc_varput(filename2,'depth_qc',depth_qc);

        clear varstruct
        varstruct.Name='lat';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'lat','_FillValue',-999.0);
        nc_attput(filename2,'lat','ancillary_variables','lat_qc');
        nc_attput(filename2,'lat','comment','Some values may be linearly interpolated.');
        nc_attput(filename2,'lat','coordinate_reference_frame','urn:ogc:crs:EPSG::4326');
        nc_attput(filename2,'lat','standard_name','latitude');
        nc_attput(filename2,'lat','long_name','Latitude');
        nc_attput(filename2,'lat','units','degrees_north');
        nc_attput(filename2,'lat','axis','Y');
        nc_attput(filename2,'lat','valid_min',-90.0);
        nc_attput(filename2,'lat','valid_max',90.0);
        %nc_attput(filename2,'lat','uncertainty',0.01);
        nc_attput(filename2,'lat','platform','platform');
        nc_attput(filename2,'lat','reference','WGS84');
        %nc_attput(filename2,'lat','sensor_name',' ');
	nc_attput(filename2,'lat','gts_ingest','true');
        %nc_attput(filename2,'lat','reference_datum','Geographical Coordinates, WGS84 projections');
        nc_attput(filename2,'lat','observation_type','measured');
        nc_varput(filename2,'lat',latv);

        %ll=latv >42;
        lat_qc=zeros(size(latv));
        %lat_qc(ll)=3;
        %ll=latv < 30;
        %lat_qc(ll)=3;

        clear varstruct
        varstruct.Name='lat_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'lat_qc','standard_name','latitude status_flag');
        nc_attput(filename2,'lat_qc','long_name','Latitude Quality Flag');
        nc_attput(filename2,'lat_qc','_FillValue',-127);
        nc_attput(filename2,'lat_qc','valid_min',0);
        nc_attput(filename2,'lat_qc','valid_max',9);
        nc_attput(filename2,'lat_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'lat_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed interpolated_value missing_value');
        nc_varput(filename2,'lat_qc',lat_qc);

        clear varstruct
        varstruct.Name='lon';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'lon','long_name','Longitude');
        nc_attput(filename2,'lon','standard_name','longitude');
        nc_attput(filename2,'lon','units','degrees_east');
        nc_attput(filename2,'lon','_FillValue',-999.0);
        nc_attput(filename2,'lon','valid_min',-180.0);
        nc_attput(filename2,'lon','valid_max',180.0);
        %nc_attput(filename2,'lon','uncertainty',0.01);
        nc_attput(filename2,'lon','axis','X');
        nc_attput(filename2,'lon','platform','platform');
        nc_attput(filename2,'lon','reference','WGS84');
        %nc_attput(filename2,'lon','sensor_name',' ');
        nc_varput(filename2,'lon',lonv);
	nc_attput(filename2,'lon','gts_ingest','true');
        nc_attput(filename2,'lon','comment','Some values may be linearly interpolated from fixes at the start and end of dives.');
        %nc_attput(filename2,'lon','reference_datum','Geographical Coordinates, WGS84 projections');
        nc_attput(filename2,'lon','ancillary_variables','lon_qc');
        nc_attput(filename2,'lon','observation_type','measured');
        nc_attput(filename2,'lon','coordinate_reference_frame','urn:ogc:crs:EPSG::4326');

        %ll=lonv >-120;
        lon_qc=zeros(size(lonv));
        %lon_qc(ll)=3;
        %ll=lonv < -128;
        %lon_qc(ll)=3;

        clear varstruct
        varstruct.Name='lon_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'lon_qc','standard_name','longitude status_flag');
        nc_attput(filename2,'lon_qc','long_name','Longitude Quality Flag');
        nc_attput(filename2,'lon_qc','_FillValue',-127);
        nc_attput(filename2,'lon_qc','valid_min',0);
        nc_attput(filename2,'lon_qc','valid_max',9);
        nc_attput(filename2,'lon_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'lon_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed interpolated_value missing_value');
        nc_varput(filename2,'lon_qc',lon_qc);

        clear varstruct
        varstruct.Name='pressure';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'pressure','long_name','Pressure'); % yes
        nc_attput(filename2,'pressure','standard_name','sea_water_pressure'); %yes
        nc_attput(filename2,'pressure','units','dbar'); % yes
        nc_attput(filename2,'pressure','positive','down'); %yes
        nc_attput(filename2,'pressure','_FillValue',-999.0); % yes
        nc_attput(filename2,'pressure','valid_min',0.0); % yes
        nc_attput(filename2,'pressure','valid_max',12000.0); %yes
        %nc_attput(filename2,'pressure','uncertainty',0.1);
        nc_attput(filename2,'pressure','reference_datum','sea_surface'); % yes
        nc_attput(filename2,'pressure','observation_type','measured'); %yes
        %nc_attput(filename2,'pressure','axis','Z');
        nc_attput(filename2,'pressure','platform','platform'); % yes
        nc_attput(filename2,'pressure','instrument','instrument_ctd'); %yes
        nc_attput(filename2,'pressure','sensor_name',' ');
	nc_attput(filename2,'pressure','gts_ingest','true');
        nc_attput(filename2,'pressure','accuracy',0.1); % yes
        nc_attput(filename2,'pressure','precision',0.1); % yes
        nc_attput(filename2,'pressure','resolution',0.1); %yes
        nc_attput(filename2,'pressure','ancillary_variables','pressure_qc'); % yes
        nc_attput(filename2,'pressure','comment',' '); % yes
        nc_varput(filename2,'pressure',press);

        press_qc=zeros(size(press));

        clear varstruct
        varstruct.Name='pressure_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'pressure_qc',press_qc);
        nc_attput(filename2,'pressure_qc','long_name','Pressure Quality Flag');
        nc_attput(filename2,'pressure_qc','standard_name','sea_water_pressure status_flag');
        nc_attput(filename2,'pressure_qc','_FillValue',-127);
        nc_attput(filename2,'pressure_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'pressure_qc','valid_min',0);
        nc_attput(filename2,'pressure_qc','valid_max',9);
        nc_attput(filename2,'pressure_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

        clear varstruct
        varstruct.Name='temperature';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'temperature',ttemp);
        nc_attput(filename2,'temperature','long_name','Temperature'); % yes
        nc_attput(filename2,'temperature','standard_name','sea_water_temperature'); %yes
        nc_attput(filename2,'temperature','units','Celsius'); % yes
        nc_attput(filename2,'temperature','_FillValue',-1e34); % yes
        nc_attput(filename2,'temperature','missing_value',-1e34);
        nc_attput(filename2,'temperature','valid_min',0.0); % yes
        nc_attput(filename2,'temperature','valid_max',30.0); %yes
        nc_attput(filename2,'temperature','resolution',0.001); % yes
        %nc_attput(filename2,'temperature','uncertainty',0.002);
        %nc_attput(filename2,'temperature','coordinates','lon lat depth time');
        nc_attput(filename2,'temperature','platform','platform'); % yes
        nc_attput(filename2,'temperature','instrument','instrument_ctd'); % yes
        nc_attput(filename2,'temperature','observation_type','measured'); % yes
        %nc_attput(filename2,'temperature','sensor_name',' ');
        nc_attput(filename2,'temperature','gts_ingest','true');
        nc_attput(filename2,'temperature','ancillary_variables','temperature_qc'); % yes
        nc_attput(filename2,'temperature','accuracy',0.002); % yes
        nc_attput(filename2,'temperature','precision',0.001); % yes
        nc_attput(filename2,'temperature','comment','no comment');

    %    temp_qc=ones(size(ttemp));
    %    ll=temp==-1e34;
    %    temp_qc(ll)=-127;

        clear varstruct
        varstruct.Name='temperature_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'temperature_qc',str2num(temp_qc)); %#ok<ST2NM>
        nc_attput(filename2,'temperature_qc','long_name','Temperature Quality Flag');
        nc_attput(filename2,'temperature_qc','standard_name','sea_water_temperuature status_flag');
        nc_attput(filename2,'temperature_qc','_FillValue',-127);
        nc_attput(filename2,'temperature_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'temperature_qc','valid_min',0);
        nc_attput(filename2,'temperature_qc','valid_max',9);
        nc_attput(filename2,'temperature_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

        clear varstruct
        varstruct.Name='salinity';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'salinity',tsalt);
        nc_attput(filename2,'salinity','long_name','Sea Water Salinity in-situ PSS 1978 scale');
        nc_attput(filename2,'salinity','standard_name','sea_water_practical_salinity');
        nc_attput(filename2,'salinity','units','0.001');
        nc_attput(filename2,'salinity','_FillValue',-1e34);
        nc_attput(filename2,'salinity','missing_value',-1e34);
        nc_attput(filename2,'salinity','valid_min',0.0);
        nc_attput(filename2,'salinity','valid_max',38.0);
        nc_attput(filename2,'salinity','resolution',0.001);
        nc_attput(filename2,'salinity','uncertainty',0.002);
        nc_attput(filename2,'salinity','platform','platform');
        nc_attput(filename2,'salinity','observation_type','calculated');
        nc_attput(filename2,'salinity','instrument','instrument_ctd');
        nc_attput(filename2,'salinity','coordinates','lon lat depth time');
        nc_attput(filename2,'salinity','sensor_name',' ');
	nc_attput(filename2,'salinity','gts_ingest','true');
        nc_attput(filename2,'salinity','ancillary_variables','salinity_qc');
        nc_attput(filename2,'salinity','comment','Salinity is based upon the Practical Salinity Scale of 1978 (PSS78) and is without dimensions. The CF-1.4 convention recognizes that PSS78 is dimensionless yet recommends a unit of 0.001 to reflect parts per thousand');
        nc_attput(filename2,'salinity','accuracy',0.002);
        nc_attput(filename2,'salinity','precision',0.001);

    %     salt_qc=ones(size(tsalt));
    %     ll=salt==-1e34;
    %     salt_qc(ll)=-127;
    %     ll=salt < 33;
    %     salt_qc(ll)=3;

        clear varstruct
        varstruct.Name='salinity_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'salinity_qc',str2num(salt_qc)); %#ok<ST2NM>
        nc_attput(filename2,'salinity_qc','long_name','Salinity Quality Flag');
        nc_attput(filename2,'salinity_qc','standard_name','sea_water_practical_salinity status_flag');
        nc_attput(filename2,'salinity_qc','_FillValue',-127);
        nc_attput(filename2,'salinity_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'salinity_qc','valid_min',0);
        nc_attput(filename2,'salinity_qc','valid_max',9);
        nc_attput(filename2,'salinity_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

        clear varstruct
        varstruct.Name='conductivity';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'conductivity',tcond);
        nc_attput(filename2,'conductivity','long_name','Conductivity'); %yes
        nc_attput(filename2,'conductivity','standard_name','sea_water_electrical_conductivity'); %yes
        nc_attput(filename2,'conductivity','units','S m-1'); %yes
        nc_attput(filename2,'conductivity','_FillValue',-1e34); %yes
        %nc_attput(filename2,'conductivity','missing_value',-1e34);
        nc_attput(filename2,'conductivity','valid_min',0.0); %yes
        nc_attput(filename2,'conductivity','valid_max',38.0); % yes
        nc_attput(filename2,'conductivity','resolution',0.001); % yes
        %nc_attput(filename2,'conductivity','uncertainty',0.002);
        nc_attput(filename2,'conductivity','platform','platform'); %yes
        nc_attput(filename2,'conductivity','observation_type','calculated'); % yes
        nc_attput(filename2,'conductivity','instrument','instrument_ctd'); %yes
        nc_attput(filename2,'conductivity','coordinates','lon lat depth time');
        %nc_attput(filename2,'conductivity','sensor_name',' ');
        nc_attput(filename2,'conductivity','ancillary_variables','conductivity_qc'); %yes
        nc_attput(filename2,'conductivity','accuracy',0.002); % yes
        nc_attput(filename2,'conductivity','precision',0.001); % yes

        clear varstruct
        varstruct.Name='conductivity_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'conductivity_qc',str2num(cond_qc)); %#ok<ST2NM>
        nc_attput(filename2,'conductivity_qc','long_name','conductivity Quality Flag');
        nc_attput(filename2,'conductivity_qc','standard_name','sea_water_electrical_conductivity status_flag');
        nc_attput(filename2,'conductivity_qc','_FillValue',-127);
        nc_attput(filename2,'conductivity_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'conductivity_qc','valid_min',0);
        nc_attput(filename2,'conductivity_qc','valid_max',9);
        nc_attput(filename2,'conductivity_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

        clear varstruct
        varstruct.Name='density';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'density',density);
        nc_attput(filename2,'density','long_name','Density'); % yes
        nc_attput(filename2,'density','standard_name','sea_water_density'); %yes
        nc_attput(filename2,'density','units','kg m-3');% yes
        nc_attput(filename2,'density','_FillValue',-1e34); %yes
        nc_attput(filename2,'density','missing_value',-1e34);
        nc_attput(filename2,'density','valid_min',1000.0); %yes
        nc_attput(filename2,'density','valid_max',1038.0);%yes
        nc_attput(filename2,'density','resolution',0.01);%yes
        %nc_attput(filename2,'density','uncertainty',0.02);
        nc_attput(filename2,'density','platform','platform'); %yes
        nc_attput(filename2,'density','observation_type','calculated'); %yes
        nc_attput(filename2,'density','instrument','instrument_ctd'); %yes
        nc_attput(filename2,'density','coordinates','lon lat depth time');
        %nc_attput(filename2,'density','sensor_name',' ');
        nc_attput(filename2,'density','ancillary_variables','density_qc'); %yes
        nc_attput(filename2,'density','accuracy',0.02); %yes
        nc_attput(filename2,'density','precision',0.01); %yes

        density_qc=ones(size(density));
        clear varstruct
        varstruct.Name='density_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'density_qc',density_qc);
        nc_attput(filename2,'density_qc','long_name','Density Quality Flag');
        nc_attput(filename2,'density_qc','standard_name','sea_water_density status_flag');
        nc_attput(filename2,'density_qc','_FillValue',-127);
        nc_attput(filename2,'density_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'density_qc','valid_min',0);
        nc_attput(filename2,'density_qc','valid_max',9);
        nc_attput(filename2,'density_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

        clear varstruct
        varstruct.Name='fluorescence';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'fluorescence',tfluo);
        nc_attput(filename2,'fluorescence','long_name','Fluorescence'); % yes
%        nc_attput(filename2,'fluorescence','units','counts');
        nc_attput(filename2,'fluorescence','units','microgram/L'); % yes
        nc_attput(filename2,'fluorescence','standard_name','mass_concentration_of_chlorophyll_in_sea_water');
        nc_attput(filename2,'fluorescence','_FillValue',-1e34); % yes
        %nc_attput(filename2,'fluorescence','missing_value',-1e34);
        nc_attput(filename2,'fluorescence','valid_min',0.0); % yes
        nc_attput(filename2,'fluorescence','valid_max',19.0); % yes
        nc_attput(filename2,'fluorescence','resolution',0.001); % yes
        nc_attput(filename2,'fluorescence','uncertainty',0.002);
        nc_attput(filename2,'fluorescence','platform','platform'); % yes
        nc_attput(filename2,'fluorescence','observation_type','measured'); % yes
        nc_attput(filename2,'fluorescence','instrument','instrument_ctd'); % yes
        %nc_attput(filename2,'fluorescence','coordinates','lon lat depth time');
        %nc_attput(filename2,'fluorescence','sensor_name',' ');
        nc_attput(filename2,'fluorescence','accuracy',0.001); % yes
        nc_attput(filename2,'fluorescence','precision',0.001); % yes
        nc_attput(filename2,'fluorescence','comment','Fluorescence'); % yes
        nc_attput(filename2,'fluorescence','ancillary_variables','fluorescence_qc'); %yes

        fluo_qc=zeros(size(tfluo));

        clear varstruct
        varstruct.Name='fluorescence_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'fluorescence_qc',fluo_qc);
        nc_attput(filename2,'fluorescence_qc','long_name','Fluorescence Quality Flag');
        nc_attput(filename2,'fluorescence_qc','_FillValue',-127);
        nc_attput(filename2,'fluorescence_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'fluorescence_qc','valid_min',0);
        nc_attput(filename2,'fluorescence_qc','valid_max',9);
        nc_attput(filename2,'fluorescence_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

% 
        clear varstruct
        varstruct.Name='cdom';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'cdom',cdom);
        nc_attput(filename2,'cdom','long_name','Concentration_of_colored_dissolved_organic_matter'); % yes
%        nc_attput(filename2,'cdom','units','counts');
        nc_attput(filename2,'cdom','units','ppb/L'); % yes
        nc_attput(filename2,'cdom','_FillValue',-1e34); % yes
    %	nc_attput(filename2,'cdom','missing_value',-1e34);
        nc_attput(filename2,'cdom','valid_min',0.0); % yes
        nc_attput(filename2,'cdom','valid_max',65.0); % yes
        nc_attput(filename2,'cdom','resolution',0.001); % yes
    %	nc_attput(filename2,'cdom','uncertainty',0.002);
        nc_attput(filename2,'cdom','platform','platform'); % yes
        nc_attput(filename2,'cdom','observation_type','measured'); % yes
        nc_attput(filename2,'cdom','instrument','instrument_ctd'); % yes
    %    nc_attput(filename2,'cdom','coordinates','lon lat depth time');
    %    nc_attput(filename2,'cdom','sensor_name',' ');
        nc_attput(filename2,'cdom','accuracy',' '); % yes
        nc_attput(filename2,'cdom','precision',' '); % yes
        nc_attput(filename2,'cdom','ancillary_variables','cdom_qc'); % yes
        nc_attput(filename2,'cdom','comment',' '); % yes

        cdom_qc=zeros(size(cdom));

        clear varstruct
        varstruct.Name='cdom_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'cdom_qc',cdom_qc);
        nc_attput(filename2,'cdom_qc','long_name','CDOM Quality Flag');
        nc_attput(filename2,'cdom_qc','_FillValue',-127);
        nc_attput(filename2,'cdom_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'cdom_qc','valid_min',0);
        nc_attput(filename2,'cdom_qc','valid_max',9);
        nc_attput(filename2,'cdom_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

        clear varstruct
        varstruct.Name='opbs';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'opbs',backscatter);
        nc_attput(filename2,'opbs','long_name','optical_backscattering_coefficient 600nm'); % yes
%        nc_attput(filename2,'opbs','units','counts');
        nc_attput(filename2,'opbs','units','m^-1'); % yes
        nc_attput(filename2,'opbs','_FillValue',-1e34); % yes
    %	nc_attput(filename2,'opbs','missing_value',-1e34);
        nc_attput(filename2,'opbs','valid_min',0.0); % yes
        nc_attput(filename2,'opbs','valid_max',2000.0); % yes
        nc_attput(filename2,'opbs','resolution',0.001); %yes
        nc_attput(filename2,'opbs','uncertainty',0.002);
        nc_attput(filename2,'opbs','platform','platform'); %yes
        nc_attput(filename2,'opbs','observation_type','measured'); % yes
        nc_attput(filename2,'opbs','instrument','instrument_ctd'); % yes
    %    nc_attput(filename2,'opbs','coordinates','lon lat depth time');
    %    nc_attput(filename2,'opbs','sensor_name',' ');
        nc_attput(filename2,'opbs','accuracy',' '); % yes
        nc_attput(filename2,'opbs','precision',' '); % yes
        nc_attput(filename2,'opbs','ancillary_variables','opbs_qc'); % yes
        nc_attput(filename2,'opbs','comment',' ');

        backscatter_qc=zeros(size(backscatter));

        clear varstruct
        varstruct.Name='opbs_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'opbs_qc',backscatter_qc);
        nc_attput(filename2,'opbs_qc','long_name','Optical Backscatter coefficient Quality Flag');
        nc_attput(filename2,'opbs_qc','_FillValue',-127);
        nc_attput(filename2,'opbs_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'opbs_qc','valid_min',0);
        nc_attput(filename2,'opbs_qc','valid_max',9);
        nc_attput(filename2,'opbs_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

        clear varstruct
        varstruct.Name='oxygen';
        varstruct.Nctype='double';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        nc_varput(filename2,'oxygen',oxyg);
        nc_attput(filename2,'oxygen','long_name','moles_of_oxygen_per_unit_mass_in_sea_water'); % yes
        nc_attput(filename2,'oxygen','standard_name','moles_of_oxygen_per_unit_mass_in_sea_water'); % yes
        %nc_attput(filename2,'oxygen','standard_name','mole_concentration_of_dissolved_molecular_oxygen_in_sea_water');
        nc_attput(filename2,'oxygen','units','micromol/kg'); % yes
        nc_attput(filename2,'oxygen','_FillValue',-1e34); % yes
    %	nc_attput(filename2,'oxygen','missing_value',-1e34);
        nc_attput(filename2,'oxygen','valid_min',0.0); % yes
        nc_attput(filename2,'oxygen','valid_max',400.0); %yes
        nc_attput(filename2,'oxygen','resolution',0.001); % yes
    %	nc_attput(filename2,'oxygen','uncertainty',0.002);
        nc_attput(filename2,'oxygen','platform','platform'); % yes
        nc_attput(filename2,'oxygen','observation_type','measured'); % yes
        nc_attput(filename2,'oxygen','instrument','instrument_ctd'); % yes
    %    nc_attput(filename2,'oxygen','coordinates','lon lat depth time');
    %    nc_attput(filename2,'oxygen','sensor_name',' ');
	nc_attput(filename2,'oxygen','gts_ingest','true');
        nc_attput(filename2,'oxygen','accuracy',0.001); % yes
        nc_attput(filename2,'oxygen','precision',0.002); % yes
        nc_attput(filename2,'oxygen','ancillary_variables','oxygen_qc'); % yes
        nc_attput(filename2,'oxygen','comment','Provider says sensor may be bad');


        clear varstruct
        varstruct.Name='oxygen_qc';
        varstruct.Nctype='byte';
        varstruct.Dimension={'time'};
        nc_addvar(filename2,varstruct);
        try
        	nc_varput(filename2,'oxygen_qc',str2num(oxyqc)); %#ok<ST2NM>
        catch %#ok<CTCH>
            nc_varput(filename2,'oxygen_qc',oxyqc);
        end
        nc_attput(filename2,'oxygen_qc','standard_name','moles_of_oxygen_per_unit_mass_in_sea_water status_flag');
        %nc_attput(filename2,'oxygen_qc','standard_name','mole_condentration_of_dissolved_molecular_oxygen_in_sea_water status_flag');
        nc_attput(filename2,'oxygen_qc','long_name','Oxygen Quality Flag');
        nc_attput(filename2,'oxygen_qc','_FillValue',-127);
        nc_attput(filename2,'oxygen_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'oxygen_qc','valid_min',0);
        nc_attput(filename2,'oxygen_qc','valid_max',9);
        nc_attput(filename2,'oxygen_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

        % create the profile variable
        clear varstruct;
        varstruct.Name='profile_id';
        varstruct.Nctype='int';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'profile_id','_FillValue',-999);
        nc_attput(filename2,'profile_id','comment','Sequential profile number within the trajectory. This value is unique in each file that is part of a single trajectory/deployment');
        nc_attput(filename2,'profile_id','long_name','ProfileID');
        nc_attput(filename2,'profile_id','valid_min',1);
        nc_attput(filename2,'profile_id','valid_max',214783647);
        nc_varput(filename2,'profile_id',iprofile); % Note this number needs to be computed!!!!
        % 
        clear varstruct;
        varstruct.Name='profile_time';
        varstruct.Nctype='double';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'profile_time','_FillValue',-999);
        nc_attput(filename2,'profile_time','calendar','gregorian');
        nc_attput(filename2,'profile_time','comment','Timestamp corresponding to the mid-point of the profile');
        nc_attput(filename2,'profile_time','long_name','Profile Center Time');
        nc_attput(filename2,'profile_time','observation_type','calculated');
        nc_attput(filename2,'profile_time','platform','platform');
        nc_attput(filename2,'profile_time','standard_name','time');
        nc_attput(filename2,'profile_time','units','seconds since 1970-01-01T00:00:00Z');
        nc_attput(filename2,'profile_time','ancillary_variables','profile_time_qc');
        nc_varput(filename2,'profile_time',ptime);
        %
        clear varstruct;
        varstruct.Name='profile_time_qc';
        varstruct.Nctype='byte';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'profile_time_qc','_FillValue',-127);
        nc_attput(filename2,'profile_time_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');
        nc_attput(filename2,'profile_time_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'profile_time_qc','long_name','profile_time Quality Flag');
        nc_attput(filename2,'profile_time_qc','standard_name','time status_flag');
        nc_attput(filename2,'profile_time_qc','valid_max',9);
        nc_attput(filename2,'profile_time_qc','valid_min',0);
        nc_varput(filename2,'profile_time_qc',1);

        clear varstruct;
        varstruct.Name='profile_lat';
        varstruct.Nctype='double';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'profile_lat','_FillValue',-999);
        nc_attput(filename2,'profile_lat','comment','Value is interpolated to provide an estimate of the latitude at the mid-point of the profile');
        nc_attput(filename2,'profile_lat','long_name','Profile Center Latitude');
        nc_attput(filename2,'profile_lat','observation_type','calculated');
        nc_attput(filename2,'profile_lat','platform','platform');
        nc_attput(filename2,'profile_lat','standard_name','latitude');
        nc_attput(filename2,'profile_lat','units','degrees_north');
        nc_attput(filename2,'profile_lat','valid_max',90);
        nc_attput(filename2,'profile_lat','valid_min',-90);
        nc_attput(filename2,'profile_lat','ancillary_variables','profile_lat_qc');
        nc_varput(filename2,'profile_lat',lat_uv);

        clear varstruct;
        varstruct.Name='profile_lat_qc';
        varstruct.Nctype='byte';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'profile_lat_qc','_FillValue',-127);
        nc_attput(filename2,'profile_lat_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');
        nc_attput(filename2,'profile_lat_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'profile_lat_qc','long_name','profile_lat Quality Flag');
        nc_attput(filename2,'profile_lat_qc','standard_name','latitude status_flag');
        nc_attput(filename2,'profile_lat_qc','valid_max',9);
        nc_attput(filename2,'profile_lat_qc','valid_min',0);
        nc_varput(filename2,'profile_lat_qc',1);

        clear varstruct;
        varstruct.Name='profile_lon';
        varstruct.Nctype='double';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'profile_lon','_FillValue',-999);
        nc_attput(filename2,'profile_lon','comment','Value is interpolated to provide an estimate of the latitude at the mid-point of the profile');
        nc_attput(filename2,'profile_lon','long_name','Profile Center Longitude');
        nc_attput(filename2,'profile_lon','observation_type','calculated');
        nc_attput(filename2,'profile_lon','platform','platform');
        nc_attput(filename2,'profile_lon','standard_name','longitude');
        nc_attput(filename2,'profile_lon','units','degrees_east');
        nc_attput(filename2,'profile_lon','valid_max',180);
        nc_attput(filename2,'profile_lon','valid_min',-180);
        nc_attput(filename2,'profile_lon','ancillary_variables','profile_lon_qc');
        nc_varput(filename2,'profile_lon',lon_uv);

        clear varstruct;
        varstruct.Name='profile_lon_qc';
        varstruct.Nctype='byte';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'profile_lon_qc','_FillValue',-127);
        nc_attput(filename2,'profile_lon_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');
        nc_attput(filename2,'profile_lon_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'profile_lon_qc','long_name','profile_lon Quality Flag');
        nc_attput(filename2,'profile_lon_qc','standard_name','longitude status_flag');
        nc_attput(filename2,'profile_lon_qc','valid_max',9);
        nc_attput(filename2,'profile_lon_qc','valid_min',0);
        nc_varput(filename2,'profile_lon_qc',1);

        clear varstruct
        % what if time(1) or time(end) is NaN?
        varstruct.Name='time_uv';
        varstruct.Nctype='double';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'time_uv','_FillValue',-999.);
        nc_attput(filename2,'time_uv','calendar','gregorian');
        nc_attput(filename2,'time_uv','comment','The depth-averaged current is an estimate of the net current measured while the glider is underwater.  The values is calculated over the entire underwater segment, which may consist of 1 or more dives.');
        nc_attput(filename2,'time_uv','long_name','Depth-Averaged Time');
        nc_attput(filename2,'time_uv','observation_type','calculated');
        nc_attput(filename2,'time_uv','standard_name','time');
        nc_attput(filename2,'time_uv','units','seconds since 1970-01-01T00:00:00Z');
        nc_attput(filename2,'time_uv','ancillary_variables','time_uv_qc');
        nc_varput(filename2,'time_uv',time_uv);
        clear varstruct;
        varstruct.Name='time_uv_qc';
        varstruct.Nctype='byte';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'time_uv_qc','_FillValue',-127);
        nc_attput(filename2,'time_uv_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');
        nc_attput(filename2,'time_uv_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'time_uv_qc','long_name','time_uv Quality Flag');
        nc_attput(filename2,'time_uv_qc','standard_name','time status_flag');
        nc_attput(filename2,'time_uv_qc','valid_max',9);
        nc_attput(filename2,'time_uv_qc','valid_min',0);
        nc_varput(filename2,'time_uv_qc',1);

        clear varstruct;
        varstruct.Name='lat_uv';
        varstruct.Nctype='double';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'lat_uv','_FillValue',-999.0);
        nc_attput(filename2,'lat_uv','comment','The depth-averaged current is an estimate of the net current measured while the glider is underwater.  The value is calculated over the entire underwater segment, which may consist of 1 or more dives.');
        nc_attput(filename2,'lat_uv','long_name','Depth-Averaged Latitude');
        nc_attput(filename2,'lat_uv','observation_type','calculated');
        nc_attput(filename2,'lat_uv','platform','platform');
        nc_attput(filename2,'lat_uv','standard_name','latitude');
        nc_attput(filename2,'lat_uv','units','degrees_north');
        nc_attput(filename2,'lat_uv','valid_max',90);
        nc_attput(filename2,'lat_uv','valid_min',-90);
        nc_attput(filename2,'lat_uv','ancillary_variables','lat_uv_qc');
        nc_varput(filename2,'lat_uv',lat_uv);
        clear varstruct;
        varstruct.Name='lat_uv_qc';
        varstruct.Nctype='byte';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'lat_uv_qc','_FillValue',-127);
        nc_attput(filename2,'lat_uv_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');
        nc_attput(filename2,'lat_uv_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'lat_uv_qc','long_name','lat_uv Quality Flag');
        nc_attput(filename2,'lat_uv_qc','standard_name','latitude status_flag');
        nc_attput(filename2,'lat_uv_qc','valid_max',9);
        nc_attput(filename2,'lat_uv_qc','valid_min',0);
        nc_varput(filename2,'lat_uv_qc',1);

        clear varstruct;
        varstruct.Name='lon_uv';
        varstruct.Nctype='double';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'lon_uv','_FillValue',-999.0);
        nc_attput(filename2,'lon_uv','comment','The depth-averaged current is an estimate of the net current measured while the glider is underwater.  The value is calculated over the entire underwater segment, which may consist of 1 or more dives');
        nc_attput(filename2,'lon_uv','long_name','Depth-Averaged Longitude');
        nc_attput(filename2,'lon_uv','observation_type','calculated');
        nc_attput(filename2,'lon_uv','platform','platform');
        nc_attput(filename2,'lon_uv','standard_name','longitude');
        nc_attput(filename2,'lon_uv','units','degrees_east');
        nc_attput(filename2,'lon_uv','valid_min',-180);
        nc_attput(filename2,'lon_uv','valid_max',180);
        nc_attput(filename2,'lon_uv','ancillary_variables','lon_uv_qc');
        nc_varput(filename2,'lon_uv',lon_uv);
        clear varstruct;
        varstruct.Name='lon_uv_qc';
        varstruct.Nctype='byte';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'lon_uv_qc','_FillValue',-127);
        nc_attput(filename2,'lon_uv_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');
        nc_attput(filename2,'lon_uv_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'lon_uv_qc','long_name','lon_uv Quality Flag');
        nc_attput(filename2,'lon_uv_qc','standard_name','longitude status_flag');
        nc_attput(filename2,'lon_uv_qc','valid_max',9);
        nc_attput(filename2,'lon_uv_qc','valid_min',0);
        nc_varput(filename2,'lon_uv_qc',1);

        clear varstruct;
        varstruct.Name='u';
        varstruct.Nctype='double';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'u','_FillValue',-999.);
        nc_attput(filename2,'u','comment','The depth-averaged current is and estimate of the net current measured while the glider is underwater.  The value is calculated over the entire underwater segment, which may consist of 1 or more dives');
        nc_attput(filename2,'u','long_name','Depth-Averaged Eastward Sea Water Velocity');
        nc_attput(filename2,'u','observation_type','calculated');
        nc_attput(filename2,'u','platform','platform');
        nc_attput(filename2,'u','standard_name','eastward_sea_water_velocity');    
        nc_attput(filename2,'u','units','m s-1');
        nc_attput(filename2,'u','valid_min',-10);
        nc_attput(filename2,'u','valid_max',10);  
        nc_attput(filename2,'u','ancillary_variables','u_qc');
        nc_varput(filename2,'u',ucurr');

        clear varstruct
        varstruct.Name='u_qc';
        varstruct.Nctype='byte';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'u_qc','_FillValue',-127);
        nc_attput(filename2,'u_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');
        nc_attput(filename2,'u_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'u_qc','long_name','u Quality Flag');
        nc_attput(filename2,'u_qc','standard_name','eastward_sea_water_velocity status_flag');
        nc_attput(filename2,'u_qc','valid_max',9);
        nc_attput(filename2,'u_qc','valid_min',0);
        if ischar(u_qc)==1
            u_qc=str2num(u_qc); %#ok<ST2NM>
        end
        nc_varput(filename2,'u_qc',u_qc);

        clear varstruct;
        varstruct.Name='v';
        varstruct.Nctype='double';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'v','_FillValue',-999.);
        nc_attput(filename2,'v','comment','The depth-averaged current is an estimate of the net current measured while the glider is underwater.  The value is calculated over the entire underwater segment, which may consist of 1 or more dives.');
        nc_attput(filename2,'v','units','m s-1');
        nc_attput(filename2,'v','standard_name','northward_sea_water_velocity');
        nc_attput(filename2,'v','valid_min',-10);
        nc_attput(filename2,'v','valid_max',10);
        nc_attput(filename2,'v','long_name','Northward Sea Water Velocity');
        nc_attput(filename2,'v','observation_type','calculated');
        nc_attput(filename2,'v','coordinates','lon_uv lat_uv time_uv');
        nc_attput(filename2,'v','platform','platform');
        nc_attput(filename2,'v','sensor_name',' ');
        nc_varput(filename2,'v',vcurr');

        clear varstruct
        varstruct.Name='v_qc';
        varstruct.Nctype='byte';
        nc_addvar(filename2,varstruct);
        if ischar(v_qc)==1
            v_qc=str2num(v_qc); %#ok<ST2NM>
        end
        nc_varput(filename2,'v_qc',v_qc);
        nc_attput(filename2,'v_qc','long_name','v Quality Flag');
        nc_attput(filename2,'v_qc','standard_name','northward_sea_water_velocity status_flag');
        nc_attput(filename2,'v_qc','_FillValue',-127);
        nc_attput(filename2,'v_qc','flag_values',[0,1,2,3,4,5,6,7,8,9]);
        nc_attput(filename2,'v_qc','valid_min',0);
        nc_attput(filename2,'v_qc','valid_max',9);
        nc_attput(filename2,'v_qc','flag_meanings','no_qc_preformed good_data probably_good_data bad_data_that_potentially_correctable bad_data value_changed interpolated_value');

        clear varstruct;
        varstruct.Name='instrument_ctd';
        varstruct.Nctype='int';
        nc_addvar(filename2,varstruct);
        nc_attput(filename2,'instrument_ctd','_FillValue',-999);
        nc_attput(filename2,'instrument_ctd','calibration_date',' ');
        nc_attput(filename2,'instrument_ctd','calibration_report',' ');
        nc_attput(filename2,'instrument_ctd','comment','unpumped CTD');
        nc_attput(filename2,'instrument_ctd','factory_calibrated',' ');
        nc_attput(filename2,'instrument_ctd','long_name','Seabird SBD 41CP Conductivity, Temperature, Depth Sensor.');
        nc_attput(filename2,'instrument_ctd','make_model','Seabird SBE 41CP');
        nc_attput(filename2,'instrument_ctd','serial_number','-1');
        nc_attput(filename2,'instrument_ctd','type','platform');
        nc_attput(filename2,'instrument_ctd','platform','platform');
        clear varstruct;
        varstruct.Name='platform';
        varstruct.Nctype='int';
        nc_addvar(filename2,varstruct);
        spid=['OSU',id{1}];
        commid=['Seaglider ',id{1}];
        nc_attput(filename2,'platform','_FillValue',-999);
        nc_attput(filename2,'platform','comment',commid);
        %nc_attput(filename2,'platform','comment','Seaglider 130');
        nc_attput(filename2,'platform','id',spid);
        %nc_attput(filename2,'platform','id','OSU130');
        nc_attput(filename2,'platform','instrument','instrument_ctd');
        nc_attput(filename2,'platform','type','platform');
        nc_attput(filename2,'platform','wmo_id',gliderwmo);
        nc_attput(filename2,'platform','long_name',commid);
        %nc_attput(filename2,'platform','long_name','Seaglider 130');
        iprofile=iprofile+1;
    end
        end
       netcdf.close(ncid1);
        %end
    else % file is empty but we need to increment by up and down casts (so 2)
        iprofile=iprofile+2;
    end % end file size 0
    %end % skip file 244
    %end
end
% %
% 
exit;







