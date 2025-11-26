%EE239AS

%Project Ray Tracing 

clc; clear all; close all; rng('shuffle');

%Siteviewer of the court of sciences
%Lat from 34.067076 to 34.07003
%Long from -118.4385 to -118.4443
Court_of_Science = 'map.osm';
viewer = siteviewer(Buildings=Court_of_Science);

%tx initial values
tx_lat = 34.06945;
tx_lon = -118.4425;
tx_ant_height = 10;
tx_power = 1; %dB check
tx_freq = 6*10^9; %Hz

%interesting tx spot: tx_lat = 34.06945; tx_lon = -118.4435;
%Move tx_lon from -118.4425 to -118.4419
%Move tx_lat from 34.06945 to 34.0685

tx = txsite(Latitude = tx_lat, ...
    Longitude = tx_lon, ...
    AntennaHeight = tx_ant_height, ...
    TransmitterPower = tx_power, ...
    TransmitterFrequency = tx_freq);

%rx initial values
rx_lat = 34.0677;
rx_lon = -118.441;
rx_ant_height = 5;

%leave rx for now
%can move rx_lon from -118.4425 to -118.4419

rx = rxsite(Latitude = rx_lat, ...
    Longitude = rx_lon, ...
    AntennaHeight = rx_ant_height);

% Create a RayTracing propagation model
pm = propagationModel("raytracing");
pm.MaxNumDiffractions = 1;
pm.MaxNumReflections = 3;
pm.MaxRelativePathLoss = 50;
pm.UseGPU = "off"; 

raytrace(tx,rx,pm,Type="pathloss")
% rays_perfect = raytrace(tx,rx,pm,Type="pathloss");
% pl_perfect = [rays_perfect{1}.PathLoss] %output path losses

%add material properties not sure of buildings are actually brick but leave
%for now
pm.BuildingsMaterial = "brick";
pm.TerrainMaterial = "concrete";

rays_materials = raytrace(tx,rx,pm,Type="pathloss");
pl_materials = [rays_materials{1}.PathLoss]; %output path losses

%data collection
%start by leaving rx just move tx
tx_lat_start = 34.06945;
tx_lat_stop = 34.06943;%34.0685
tx_lon_start = -118.4425;
tx_lon_stop = -118.4424;%-118.4419
tx_lat_step = -.00001;
tx_lon_step = .0001;

tx_lat_sweep = tx_lat_start:tx_lat_step:tx_lat_stop;
tx_lon_sweep = tx_lon_start:tx_lon_step:tx_lon_stop;

data_points = length(tx_lon_sweep) * length(tx_lat_sweep); %out for debugging to see how many points

%initialized tx locations
tx_lat_total = zeros(data_points, 1);
tx_lon_total = zeros(data_points, 1);

%rx location fixed for now
rx_lat_total = ones(data_points, 1) * rx_lat;
rx_lon_total = ones(data_points, 1) * rx_lon;

pathloss_points = cell(data_points, 1);%cell with all info
pl_los_list = zeros(data_points, 1);%list of pathloss for los paths
pl_los_indexs = zeros(data_points, 1);%list of pathloss indexes for los path

rays_count = zeros(data_points, 1);%list of total number of rays at each tx location
ray_los_present = false(data_points, 1);%whether or not the los path was found

%for organizing data for our MLP later
data_total = struct('tx_lat', {}, ...
    'tx_lon',{}, ...
    'rx_lat',{}, ...
    'rx_lon',{}, ...
    'frequency_Hz',{}, ...
    'pathloss_dB',{}, ...
    'pl_los_index',{}, ...
    'propagation_delay_s',{}, ...
    'propagation_distance_m',{}, ...
    'rays_count',{});

%sweep through values of lat and long for tx location
k = 1;
for tx_lat = tx_lat_sweep
    for tx_lon = tx_lon_sweep

        tx = txsite( Latitude = tx_lat, ...
             Longitude = tx_lon, ...
             AntennaHeight = tx_ant_height, ...
             TransmitterPower = tx_power, ...
             TransmitterFrequency = tx_freq);

        %add in building materials
        %path losses with materials accounted for for the current tx
        %location this value changes after each loop
        rays_materials = raytrace(tx,rx,pm,Type="pathloss");
        pl_materials = [rays_materials{1}.PathLoss];
        %rays = raytrace(tx, rx, pm, Type="pathloss");

        %check los path exists
        if ~isempty(rays_materials{1})
            los_pathloss = min(pl_materials);%los path should be the smallest pl
            pl_los_index = find(pl_materials == los_pathloss);%los path index
            ray_los = true;%true if there is a los path
            pathloss_points{k} = rays_materials{1};%cell with all info for the current tx location
            rays_current = length(rays_materials{1});%total number of rays for the given tx location

            los_ray_properties = rays_materials{1}(pl_los_index);%properties from the los path for a given tx location
        else
            los_pathloss = 0;
            ray_los = false;
            pathloss_points{k} = 0;
            rays_current = 0;
        end

        %mainly for initial debugging
        pl_los_list(k) = los_pathloss;%list of pathloss for los for each tx location
        pl_los_indexs(k) = pl_los_index;%list of the los indexes for each location
        rays_count(k) = rays_current;%number of rays per tx location
        ray_los_present(k) = ray_los;%list of whether or not there is a los path
        tx_lat_total(k) = tx_lat;%list of tx lat locations
        tx_lon_total(k) = tx_lon;%list of tx long locations


        %for our table data
        data_total(k).tx_lat = tx_lat;%same as tx_lat_total
        data_total(k).tx_lon = tx_lon;%same as tx_lon_total
        data_total(k).rx_lat = rx_lat;
        data_total(k).rx_lon = rx_lon;
        data_total(k).frequency_Hz = tx_freq;
        data_total(k).pathloss_dB = los_pathloss; %same as pl_los_list
        data_total(k).pl_los_index = pl_los_index; %same as pl_los_indexes
        data_total(k).propagation_delay_s = los_ray_properties.PropagationDelay;
        data_total(k).propagation_distance_m = los_ray_properties.PropagationDistance;
        data_total(k).rays_count = rays_current; %same as rays_count

        k = k + 1;
    end
end

%organize data
if k > 1 %format long messes with siteviewer so put in an if statement
    results = struct2table(data_total);
    format long;%for longer decimals to see the difference in tx locations
    disp(results);%output our table
    disp(k-1);%number of data points
end

%plot pathloss for los paths vs distance from tx (propagation distance)
figure(1);
plot(results.propagation_distance_m,results.pathloss_dB);
title('Path Loss for los path vs Propagation Distance');
xlabel('Propagation Distance (m)');
ylabel('Path loss (dB)');

%now add MLP to predict los pathloss with distance from tx to rx
