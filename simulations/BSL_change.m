%--------------------------------------------------------------------------------------------------- 
% Simulation for FreeMat v4.0 (Matlab clone with GPLv2 license) 
% 
% Purpose: Find out how the Btcoin Block Size Limit (BSL) evolves with the rule set of BIP10X, in 
%          the corner case that the growth or decline rate is determined by constraint (C-2) 
%          of BIP10X (either the normal limit, or the stretched limit of 80% miner majority). 
%          - In case of growth, this corresponds to the case that >50% (>80%) of miners continually 
%            vote for substantial Block Size Limit increase, or that the blocks are sufficiently full 
%            in each one-week average period, such that other factors do not limit the growth. 
%            In fact, if the blocks are sufficiently full, this would already be enough to cause this 
%            "50%-vote-like" BSL increase, irrespective of the actual miner votes. 
%          - In case of decline, this corresponds to the case that >50% (>80%) of miners continually 
%            vote for substantial Block Size Limit decrease, or that the blocks are sufficiently 
%            empty in a one-week average period, such that other factors do not limit the decline. 
%            In fact, if the blocks are sufficiently empty, this would already be enough to cause a 
%            "50%-vote-like" BSL decline, irrespective of the actual miner votes. 
% 
% Note: This simulation assumes 52 weeks == 1 year for simplicity (the error is 1.25 days or 0.34%). 
%       This simulation assumes further that 1 week = 1008 blocks. 
%       Since hash rate is expected to increase long-term, be it alone due to the advances in 
%       technology, reality is expected to show that 1008 blocks < 1 week. 
%       This can be accounted for by setting 'time_warp_hash_speedup_factor' accordingly. 
% 
%       As a consequence, results are slightly biased in that actual growth/decline rates under the 
%       given circumstances can be expected to be slightly stronger vs. time than what this 
%       simulation shows. 
%       On the other hand, actual growth rates cannot always be expected to be at the maximum 
%       in reality, and this effect should offset (or even over-compensate) the first one. 
%       
%       (C) 2015 by Michael_S 
%       
%--------------------------------------------------------------------------------------------------- 
close all; clear all; 

%--------------------------------------------------------------------------------------------------- 
%% --- #0) Parameter Settings: --- 

Start_Year = 2016 + 0*1/12;% e.g. 2016.5 means 1st July 2016 

NbYrs=5; % simulate for this number of years (1008*52 blocks == 52 weeks == 1 year) 

% If block times are shorter than 10 min, enter corresponding factor <1.0 here. Or vice versa: 
time_warp_hash_speedup_factor = 1.0;%[1.0] e.g. 0.9 means 9 min avg. block time 

BSL_init_MB = 1;% Initial value of the block size limit, e.g. 1 or 4 [MByte] 

Direction = 1;% 1 = grow ;  -1 = decline 

%averaging_method = 'flat';% 'flat' or 'forgetting_factor' <-- NOT used in BIP10X 
averaging_method = 'forgetting_factor';% 'flat' or 'forgetting_factor' <-- this one for BIP10X! 

% forgetting_factor only applicable if averaging_method=='forgetting_factor': 
forgetting_factor=32244/32768;% (~0.984) = eff. window length = 1/(1-0.984)=62.5 weeks = 1.2 years 

% Parameters for 'flat': (this method is not used in BIP10X - gives worse results) 
%incmax_yearAvg = 1.24;% New BSL can be max. this much higher than avg over last Yr 
%decmin_yearAvg = 0.90;% same for decrease 

% Parameters for 'forgetting_factor': (this method is used in BIP10X) 
incmax_yearAvg = 189/128;% =1.4765625;% New BSL can be max. this much higher than avg over last Yr 
decmin_yearAvg = 110/128;% =0.8593750;% same for decrease 
incmax_yearAvg2 = 247/128;% =1.9296875;% parameter for growth speed-up (needs 80% vote majority) 
decmin_yearAvg2 =  98/128;% =0.7656250;% parameter for decline speed-up (needs 80% vote majority) 

% Random Event 1: >80% miner vote: Boosted maximum growth/decline rate, stretched limits apply: 
probability_80percent_boost = 0.0;% probability that a BSL increase is boosted by >80% miner vote 
% Following pattern is followed cyclically, one step per week. If value <>0, boost condition is met: 
pattern_80percent_boost = [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]; 

% Random Event 2: Stay one step away from max growth/decline value: 
probability_one_step_less = 0.0;% probability that BSL adjustment is modified as follows: 
% BSL is one step smaller (in case of growth) or higher (in case of decline) on the BSE resolution 
% grid than what it would otherwise be. 
% Following pattern is run cyclically, 1 step p. wk. If value <>0, condition "one step less" is met: 
pattern_one_step_less = [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]; 

% Plot Screen Size - modify in dependence of your monitor's resolution: 
plot_window_width  = 900; 
plot_window_height = 360; 


%--------------------------------------------------------------------------------------------------- 
%% --- #1) Initializations: --- 

BSE = max(0,min(127,floor(8*log(BSL_init_MB+eps)/log(2))));%block size exponent, 0..127 

N = round(NbYrs*52/time_warp_hash_speedup_factor);% nb of 1008 block periods (~weeks). 

BSL_vector(1:52)=2^(BSE/8)*1e6; % [in MByte] Initialise the BSL value for the first 52 weeks 
BSL_vector = [BSL_vector, nan*ones(1,N)]; 

% Initialize BSL_LongTermAvg - only needed if averaging_method = 'forgetting_factor': 
BSL_LongTermAvg = BSL_init_MB * 1e6; 


%--------------------------------------------------------------------------------------------------- 
%% --- #2) The Simulation: --- 

if Direction == 1,% GROWTH Case 
    % Try to increase BSL as much as possible, for the given limits 
    for k = 52+1:52+N, % start with first week of the 2nd year 
        % Calculate average BSL 
        if strcmpi(averaging_method, 'flat'),% not BIP10X 
            BSL_LongTermAvg = mean(BSL_vector(k-52:k-1)); 
        elseif strcmpi(averaging_method, 'forgetting_factor'),% BIP10X ! 
            BSL_LongTermAvg = forgetting_factor*BSL_LongTermAvg + ... 
                              (1-forgetting_factor)*BSL_vector(k-1); 
        else 
            disp('ERROR: Invalid value for parameter "averaging_method"!') 
            return; 
        end 
        % Determine which long-term-change constraint applies: 
        if rand()<probability_80percent_boost, 
            incmax = incmax_yearAvg2;% boosted growth by >80% miner vote 
        else 
            incmax = incmax_yearAvg;% normal case 
        end 
        if pattern_80percent_boost(1+mod(k-52, length(pattern_80percent_boost))), 
            incmax = incmax_yearAvg2;% boosted growth by >80% miner vote 
        end 
        BSE_last=BSE; 
        % Calculate next BSL for week k, assuming miner vote and actual block sizes were progressive: 
        if (floor(2^(BSE/8)*1e6)) > BSL_LongTermAvg*incmax,% is current BSL > current constaint? 
            BSE =  floor(8*log((BSL_LongTermAvg)/1e6)/log(2)); 
        end 
        % Try to go up as much as possible, but don't go more than 6 steps up from last time: 
        while ((floor(2^((BSE+1)/8)*1e6)) <= BSL_LongTermAvg*incmax) && (BSE+1<=BSE_last+6), 
            BSE = BSE + 1; 
        end 
        if (rand()<probability_one_step_less) ... 
            || pattern_one_step_less(1+mod(k-52,length(pattern_one_step_less))), 
            % A random event causes the growth to be not quite as big as it could be: 
            BSE = BSE - 1; 
        end 
        BSL_vector(k) = floor(2^(BSE/8)*1e6); 
    end 
elseif Direction == -1,% DECLINE Case 
    % Try to decrease BSL as much as possible, for the given limits 
    for k = 52+1:52+N, % start with first week of the 2nd year 
        % Calculate average BSL 
        if strcmpi(averaging_method, 'flat'),% not BIP10X 
            BSL_LongTermAvg = mean(BSL_vector(k-52:k-1)); 
        elseif strcmpi(averaging_method, 'forgetting_factor'),% BIP10X ! 
            BSL_LongTermAvg = forgetting_factor*BSL_LongTermAvg + ... 
                              (1-forgetting_factor)*BSL_vector(k-1); 
        else 
            disp('ERROR: Invalid value for parameter "averaging_method"!') 
            return; 
        end 
        % Determine which long-term-change constraint applies: 
        if rand()<probability_80percent_boost, 
            decmin = decmin_yearAvg2;% boosted decline by >80% miner vote 
        else 
            decmin = decmin_yearAvg;% normal case 
        end 
        if pattern_80percent_boost(1+mod(k-52, length(pattern_80percent_boost))), 
           decmin = decmin_yearAvg2;% boosted decline by >80% miner vote 
        end 
        BSE_last=BSE; 
        % Calculate next BSL for week k, assuming miner vote and actual block sizes were low: 
        if (floor(2^(BSE/8)*1e6)) < BSL_LongTermAvg*decmin,% is current BSL < current constaint? 
            BSE =  floor(8*log((BSL_LongTermAvg)/1e6)/log(2)) + 1; 
        end 
        % Try to go down as much as possible, but don't go more than 6 steps down from last time: 
        while ((floor(2^((BSE-1)/8)*1e6)) >= BSL_LongTermAvg*decmin) && (BSE-1>=BSE_last-6), 
            BSE = BSE - 1; 
        end 
        if (rand()<probability_one_step_less) ... 
            || pattern_one_step_less(1+mod(k-52,length(pattern_one_step_less))), 
            % A random event causes the decline to be not quite as big as it could be: 
            BSE = BSE + 1; 
        end 
        BSL_vector(k) = floor(2^(BSE/8)*1e6); 
        %keyboard 
    end 
else 
    disp('ERROR: Invalid value for parameter "Direction"!') 
    return 
end 


%--------------------------------------------------------------------------------------------------- 
%% --- #3) Post-Processing & Display: --- 

% Year-to-year percentage change of BSL: 
% (this one is less meaningful because more "noisy", I use the other metric for display) 
BSL_percent_change_YoY = 100*(BSL_vector(53:end) ./ BSL_vector(1:end-52) - 1); 

% Yearly average percentage change of BSL since the start: (I use this for display!) 
years_tmp = (51+[1:length(BSL_vector(53:end))]) / 52;% years, without the first year of course 
factor_tmp = (BSL_vector(53:end)/BSL_vector(1)).^( 1./years_tmp ); 
BSL_percent_change_avg = 100*(factor_tmp-1); 

% ---------- Plotting ---------- 

figure; 
plot(Start_Year-1+[1:N+52]/52*time_warp_hash_speedup_factor,BSL_vector/1e6); 
grid on; 
a=axis; 
axis([Start_Year-1 Start_Year-1+(N+53)/52 0 a(4)]); 
xlabel('Year') 
ylabel('Block Size Limit [MB]') 
title(['Block Size Limit vs. Time']) 
sizefig(plot_window_width,plot_window_height) 

if 0;% Dont't plot this one - not as meaningful as the next plot (if plot wanted: change 0 -> 1) 
    figure; 
    plot(Start_Year+[1:N]/52*time_warp_hash_speedup_factor,BSL_percent_change_YoY); 
    grid on; 
    a=axis; 
    axis([Start_Year-1 Start_Year-1+(N+53)/52 min(0,a(3)) max(0,a(4))]); 
    xlabel('Year') 
    ylabel('BSL change vs. 52 weeks ago [%]') 
    title(['Year-to-Year Block Size Limit Change Rate']) 
    sizefig(plot_window_width,plot_window_height) 
end 

figure; 
plot(Start_Year+[1:N]/52*time_warp_hash_speedup_factor,BSL_percent_change_avg); 
grid on; 
a=axis; 
axis([Start_Year-1 Start_Year-1+(N+53)/52 min(0,a(3)) max(0,a(4))]); 
xlabel('Year') 
ylabel('BSL avg. yearly change [%]') 
title(['Yearly Avg. Block Size Limit Change Rate Since Year ',num2str(Start_Year-1,'%0.2f')]) 
sizefig(plot_window_width,plot_window_height)
