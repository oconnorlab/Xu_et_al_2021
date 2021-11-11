classdef Param
    
    properties(Constant)
        % Hardware
        frPerSec = 400;             % frame rate of high-speed video
        mmPerPx = 0.032;            % scale for high-speed video
        gPerVolt = 6.4;             % scale for lickport Perch signal
        vOptoAdcPerMod = 0.1058;    % volt recorded per volt modulation for opto stim
        vOptoAdcThreshold = 0.005;  % threshold voltage below which are noise (no stim)
        
        % Behavior
        minILI = 0.06;              % deboucing threshold in second for inter-lick-iterval violation
        minLen4Ang = 1;             % angles are taken only when length is above this value (in mm)
        fracLen4Shoot = 0.84;       % fraction of max length for defining shooting length and angle
        stdSeqs = {'123456', '543210'};
        backSeqs = {'1231456', '5435210'};
        fwdSeqs = {'12356', '54310'};
        zzSeqs = {'123432101234', '321012343210'};
        
        % Ephys
        minISI = 0.0025;            % threshold in second for refractory period violation
        normAddMax = 5;             % spike rate added to the maximum
        minActive = .5;             % minimal spike rate for a unit being active (exclusive)
        maxFA = 1;                  % max allowed percent refractory period violation (inclusive)
        maxContam = 15;             % max allowed percent contanimation (inclusive)
        fsPyrCutoff = [.4 .5];      % peak to trough time that separate putative FS and Pyr units
        
        % Style
        RLColor = [0 0 1];          % color for right-to-left sequence
        LRColor = [1 0 0];          % color for left-to-right sequence
        optoColor = [0 .6 1];       % color for opto
        backColor = [0 .7 0];       % color for backtracking
    end
    
    methods(Static)
        function ops = Transform(numOps)
            % Default options to transform se and to make seTb
            
            ops.description = '';
            
            % Computing spike rate
            ops.isSpkRate = true;
            ops.spkLagInSec = 0;
            ops.spkBinSize = SL.Param.minISI;
            ops.spkKerSize = 0.015;
            
            % Morphing
            ops.isMorph = false;
            ops.lickTimeType = 'mid';
            
            % Reslicing
            ops.tReslice = 0;
            
            % Trial selection
            ops.isRemoveFirst = true;
            ops.isRemoveLast = true;
            ops.maxReactionTime = Inf;   % i.e. posIndex(1) - cue
            ops.maxEndTime = Inf;        % i.e. (waterOff + 2) - cue
            
            % Standardize the range of tongue angle
            ops.isStdLickRange = false;
            
            % Alignment
            ops.alignType = '';
            
            % Trial grouping
            ops.conditionVars = {'seqId', 'opto'};
            
            % Matching
            ops.isMatch = false;
            ops.matchWin = [];
            ops.fracTrials = 1/3;
            ops.minTrials = 10;
            ops.maxTrials = Inf;
            ops.algorithm = @SL.Match.Algorithm4;   
            
            % Replicate ops
            if nargin > 0
                ops = repmat(ops, [numOps 1]);
            end
        end
        
        function ops = Resample(ops)
            % Default options for resampling data in se and outputing numeric arrays
            % e.g. used in SL.SE.GetStimArray, SL.SE.GetRespArray, SL.SE.SetStimRespArrays
            
            if ~exist('ops', 'var')
                ops = SL.Param.Transform();
            end
            
            % Variables to resample
            ops.hsvVars = {'tongue_bottom_length', 'tongue_bottom_angle', 'tongue_bottom_velocity'};
            ops.adcVars = {'tubeV', 'tubeH', 'force', 'timeVar'};
            if isfield(ops, 'conditionVars')
                ops.valVars = ops.conditionVars;
            else
                ops.valVars = {'seqId', 'opto'};
            end
            ops.derivedVars = {};
            
            % Special operations to certain variables (before resampling)
            ops.isFillLen = true;       % whether to interpolate NaN length by zero
            ops.isFillVel = false;      % whether to interpolate NaN velocity by nearest neighbor
            ops.isFillAng = false;      % whether to interpolate NaN angle by nearest neighbor
            
            % Resampling window, resolution, and method
            ops.rsWin = [];             % resampling time window, e.g. [-.5 .5]
            ops.rsBinSize = SL.Param.minISI; % resampling bin size
            ops.rsArgs = {'Method', 'nearest', 'Extrap', 'nearest'};
            
            % Average and reorganize output matrices
            ops.dimAverage = [];        % dimensions to average. 1 time, 2 variable, 3 trial
            ops.dimCombine = [];        % dimensions to collapse. 1 time, 2 variable, 3 trial
        end
        
        function rsVars = GetAllResampleVars(ops)
            % Concatenate all resampling variables to one cell array
            rsVars = [ops.hsvVars ops.adcVars ops.valVars ops.derivedVars];
        end
        
        function ops = FillMatchOptions(ops)
            % Derive and fill other parameters based on alignType
            % See SL.Param.Transform for isMatch, alignType, matchWin
            % See SL.Param.Resample for rsWin
            
            ops.isMatch = true;
            
            switch ops.alignType
                case 'init'
                    ops.matchWin = [0 .5];
                    ops.rsWin = [-.7 .5];
                case 'mid'
                    ops.matchWin = [-1 1];
                    ops.rsWin = [-.6 .6];
                case 'term'
                    ops.matchWin = [-.5 .7];
                    ops.rsWin = [-.5 .7];
                case 'seq'
                    ops.matchWin = [-1 1];
                    ops.rsWin = [-.5 .8];
                case 'iti'
                    ops.matchWin = [0 1.5];
                    ops.rsWin = [-1.3 0];
                case 'cons'
                    ops.matchWin = [-.5 1];
                    ops.rsWin = [-.5 1];
                otherwise
                    error('%s is not a valid alignment option.', ops.alignType);
            end
        end
        
        function seqId = CategorizeSeqId(seqId)
            % Convert sequence ID to ordinal categorical variable
            seqList = [SL.Param.stdSeqs, SL.Param.backSeqs, SL.Param.fwdSeqs, SL.Param.zzSeqs];
            seqList = [seqList, setdiff(unique(seqId'), seqList)];
            seqId = categorical(seqId, seqList);
        end
        
        function cc = GetAreaColors(areaNames)
            areaNames = cellstr(areaNames);
            lineColors = lines();
            for i = numel(areaNames) : -1 : 1
                switch areaNames{i}
                    case 'S1TJ'
                        cc(i,:) = lineColors(1,:);
                    case 'ALM'
                        cc(i,:) = lineColors(2,:);
                    case 'M1TJ'
                        cc(i,:) = lineColors(3,:);
                    case 'S1BF'
                        cc(i,:) = lineColors(4,:);
                    case 'M1B'
                        cc(i,:) = lineColors(5,:);
                    case 'S1L'
                        cc(i,:) = lineColors(6,:);
                    otherwise
                        cc(i,:) = [0 0 0];
                end
            end
        end
        
        function ind = FindVarIndices(vars, varList)
            % Find the positions of vars' elements in varList
            vars = cellstr(vars);
            ind = cellfun(@(x) find(strcmp(x, varList), 1), vars);
        end
        
        function a = ConvertZaberAcceleration(val)
            stepSize = 0.1905; % um, for LSMxxxB models
            a = val*10000/1.6384 * stepSize/1000; % mm/s^2
        end
    end
end

