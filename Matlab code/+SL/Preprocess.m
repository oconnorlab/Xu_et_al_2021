classdef Preprocess
    
    methods(Static)
        % Data files to master file
        function ops = GetIntanOptions(ksDir)
            % Customized processing options
            
            % Initialize options
            ops = MIntan.GetOptions();
            
            % Replace aux with another amplifier processing
            ops(2) = ops(1);
            
            % LPF
            % 1000Hz is more than enough for any LFP/EEG analysis
            ops(1).downsampleFactor = 30;
            
            % Kilosort
            % 1) Intan amplifier data was acquired with 16-bit resolution but was converted to double precision
            %    numbers. The resulting quantization is 0.195. Kilosort expects 16-bit signed integer. Thus, 
            %    we use the following function to scale amplifier data up to integer values and then cast
            %    them to int16. 
            ops(2).signalFunc = @(x) int16(x / 0.195);
            
            % 2) No need to return original amplifier data
            ops(2).isReturn = false;
            
            % 3) Specify the path of binary file
            ops(2).binFilePath = fullfile(ksDir, 'amplifier.dat');
        end
        
        function result = Tracking(vidFilePaths, varargin)
            
            % Handle user inputs
            p = inputParser();
            p.KeepUnmatched = true;
            p.addParameter('OutputDir', '', @ischar);
            p.addParameter('RoiTemplate', []);
            p.addParameter('ClassNet', [], @(x) isa(x, 'DAGNetwork'));
            p.addParameter('RegNet', [], @(x) isa(x, 'DAGNetwork'));
            p.addParameter('SegNet', [], @(x) isa(x, 'DAGNetwork'));
            p.addParameter('numWorker', 3, @isscalar);
            
            p.parse(varargin{:});
            outDir = p.Results.OutputDir;
            roiTemplate = p.Results.RoiTemplate;
            classNet = p.Results.ClassNet;
            regNet = p.Results.RegNet;
            segNet = p.Results.SegNet;
            numWorker = p.Results.numWorker;
            
            if ~isempty(outDir) && ~exist(outDir, 'dir')
                mkdir(outDir);
            end
            
            % Find ROI transformation
            if ischar(roiTemplate)
                roiTemplate = imread(roiTemplate);
            end
            vid = MNN.ReadVideo(vidFilePaths{1}, 'FrameFunc', @rgb2gray);
            [~, tform] = MNN.RoiTransform(vid(:,1:500,:), roiTemplate, 'X');
            cropSize = size(roiTemplate);
            
            % Save an example of cropped frame
            mugshot = imwarp(vid(:,:,1), tform, 'OutputView', imref2d(cropSize));
            imwrite(mugshot, fullfile(outDir, 'mugshot.png'));
            
            % Determine output sizes
            numCoor = regNet.Layers(end-1).OutputSize;
            
            % Tracking
            frame_time = cell(numel(vidFilePaths), 1);
            is_tongue_out = cell(numel(vidFilePaths), 1);
            prob_tongue_out = cell(numel(vidFilePaths), 1);
            tongue_bottom_lm = cell(numel(vidFilePaths), 1);
            tongue_bottom_area = cell(numel(vidFilePaths), 1);
            
            parfor (i = 1 : numel(vidFilePaths), numWorker)
%             for i = 1 : 0%numel(vidFilePaths)
                % Read video file
                disp(vidFilePaths{i});
                [vid, frame_time{i}, vidObj] = MNN.ReadVideo(vidFilePaths{i});
                vid = imwarp(vid, tform, 'OutputView', imref2d(cropSize));
                vid = imresize(vid, [224 224]);
                
                % Tongue detection
                [~, C_score] = classify(classNet, vid);
                reset(parallel.gpu.GPUDevice.current);  % release graphics memory
                C = C_score(:,2) > 0.5;
                
                conn = bwconncomp(~C);
                for k = 1 : length(conn.PixelIdxList)
                    if numel(conn.PixelIdxList{k}) < 8
                        C(conn.PixelIdxList{k}) = true;
                    end
                end
                
                is_tongue_out{i} = C;
                prob_tongue_out{i} = C_score(:,2);
                
                if ~any(C)
                    tongue_bottom_lm{i} = NaN(size(vid,4), numCoor, 'single');
                    continue;
                end
                
                % Tongue landmark regression
                Y = predict(regNet, vid(:,:,:,C));
                reset(parallel.gpu.GPUDevice.current);  % release graphics memory
                tongue_bottom_lm{i} = NaN(size(vid,4), numCoor, 'single');
                tongue_bottom_lm{i}(C,:) = Y;
                
                % Sementic segmentation
                if ~isempty(segNet)
                    S = semanticseg(vid(:,:,:,C), segNet, 'OutputType', 'uint8', 'MiniBatchSize', 4);
                    reset(parallel.gpu.GPUDevice.current);  % release graphics memory
                    
                    S(S == 1) = 100;
                    S(S == 2) = 0;
                    S_full = zeros(size(vid,1), size(vid,2), size(vid,4), 'uint8');
                    S_full(:,:,C) = S;
                    
                    [~, vidFileName] = fileparts(vidFilePaths{i});
                    tongue_bottom_area{i} = fullfile(outDir, [vidFileName '.mj2']);
                    
                    vwObj = VideoWriter(tongue_bottom_area{i}, 'Motion JPEG 2000');
                    vwObj.LosslessCompression = true;
                    vwObj.FrameRate = vidObj.FrameRate;
                    open(vwObj);
                    writeVideo(vwObj, permute(S_full, [1 2 4 3]));
                    close(vwObj);
                end
                
                delete(vidObj);
            end
            
            result.info.filePaths = vidFilePaths;
            result.info.roiTemplate = roiTemplate;
            result.info.tform = tform;
            result.info.cropSize = cropSize;
            result.info.mugshot = mugshot;
            
            result.frame_time = frame_time;
            result.is_tongue_out = is_tongue_out;
            result.prob_tongue_out = prob_tongue_out;
            result.tongue_bottom_lm = tongue_bottom_lm;
            result.tongue_bottom_area = tongue_bottom_area;
            
            save(fullfile(outDir, 'tracking_data.mat'), '-struct', 'result');
        end
        
        % Master file to SE
        function SessionInfo2SE(satData, se)
            
            % Parse the SatellitesViewer file name
            [~, satName] = fileparts(satData.file_path);
            satNameParts = strsplit(satName, ' ');
            sInfo.animalId = satNameParts{1};
            sInfo.sessionDatetime = datetime([satNameParts{2} ' ' satNameParts{3}], ...
                'InputFormat','yyyy-MM-dd HH-mm-ss', ...
                'Format', 'yyyy-MM-dd HH:mm:ss');
            if numel(satNameParts) > 3
                sInfo.subId = satNameParts{3};
            else
                sInfo.subId = '';
            end
            
            % Get additional info
            sSpec = sl_get_specs(sInfo.animalId, sInfo.sessionDatetime, sInfo.subId);
            sInfo = MUtil.CombineStructs(sInfo, sSpec);
            
            % Save to SE
            se.userData.sessionInfo = sInfo;
        end
        
        function Satellites2SE(satData, se)
            
            % Import data
            s = Satellites.Import(satData.txt, 'delimiterEvent', 'trialNum', 'timeScaling', 1e-3);
            
            % Select variables of interest and exclude data from pre-task episode
            fullVars = s.timeTable.Properties.VariableNames;
            
            timeVars = {'cue', 'posIndex', 'water', 'opto', 'lickOn', 'lickOff'};
            bt = table();
            for i = 1 : numel(timeVars)
                var = timeVars{i};
                if ismember(var, fullVars)
                    bt.(var) = s.timeTable{2:end, var};
                else
                    bt.(var) = NaN(height(s.timeTable)-1, 1);
                end
            end
            
            valueVars = {'trialNum', 'cue', 'posIndex', 'water', 'opto', 'nolickITI'};
            bv = table();
            for i = 1 : numel(valueVars)
                var = valueVars{i};
                if ismember(var, fullVars)
                    bv.(var) = s.valueTable{2:end, var};
                else
                    bv.(var) = NaN(height(s.valueTable)-1, 1);
                end
            end
            
            tRef = s.episodeRefTime(2:end);
            
            % Remove artifactual licks
            [bt.lickOn, bt.lickOff] = SL.Preprocess.RemoveArtifactualLicks(bt, tRef);
            
            % Map trials
            trialMap = se.userData.sessionInfo.satTrialNum;
            [bt, bv, tRef] = SL.Preprocess.MapTrial(trialMap, bt, bv, tRef);
            
            % Add tables to SE
            se.userData.sessionInfo.sessionDatetime = s.lineParts.sysTime(1); % use the time of the first message
            se.userData.satInfo = MUtil.CombineStructs(satData, s);
            se.SetTable('behavTime', bt, 'eventTimes', tRef);
            se.SetTable('behavValue', bv, 'eventValues');
        end
        
        function HSV2SE(hsvData, se)
            
            % Make table
            hsvInfo = hsvData.info;
            hsvData = rmfield(hsvData, {'info', 'tongue_bottom_area'});
            tb = struct2table(hsvData);
            tb.Properties.VariableNames{1} = 'time';
            
            % Map trials
            trialMap = se.userData.sessionInfo.hsvTrialNum;
            [tb, hsvInfo.filePaths] = SL.Preprocess.MapTrial(trialMap, tb, hsvInfo.filePaths);
            
            % Save to SE
            se.userData.hsvInfo = hsvInfo;
            se.SetTable('hsv', tb, 'timeSeries');
        end
        
        function ADC2SE(intanData, se, trialStartTime)
            
            % Separate channels into different cells
            adcSize = size(intanData.adc_data);
            adcData = mat2cell(intanData.adc_data, adcSize(1), ones(1,adcSize(2)));
            
            % Recompute timestamps
            % (original timestamps may not be monotonic if not from a single recording)
            adcFs = 1 / diff(intanData.adc_time(1:2));
            adcTime = (0 : size(adcData{1},1)-1)' / adcFs;
            
            % Find channel names
            adcChanName = {'lickportV', 'lickportH', 'tubeV', 'tubeH', 'opto1', 'opto2', 'piezo'};
            adcChanName = adcChanName(1:adcSize(2));
            
            % Make table
            [tb, preTb] = MSessionExplorer.MakeTimeSeriesTable(adcTime, adcData, ...
                'DelimiterTimes', trialStartTime, ...
                'VariableNames', adcChanName);
            
            % Map trials
            trialMap = se.userData.sessionInfo.intanTrialNum;
            tb = SL.Preprocess.MapTrial(trialMap, tb);
            
            % Save to SE
            se.userData.intanInfo.adc_table_sample_rate = adcFs;
            se.userData.preTaskData.adc = preTb;
            se.SetTable('adc', tb, 'timeSeries');
        end
        
        function LFP2SE(intanData, se, trialStartTime)
            
            % Compute average signal
            ampData = intanData.amplifier_data;
            [ampData, ~, ampStd] = zscore(ampData);
            ampData = median(ampData, 2) * median(ampStd);
            
            % Downsample
            ampData = MMath.Decimate(ampData, 5);
            ampTime = intanData.amplifier_time;
            ampTime = downsample(ampTime, 5);
            
            % Recompute timestamps
            % (original timestamps may not be monotonic if not from a single recording)
            ampFs = 1 / diff(ampTime(1:2));
            ampTime = (0 : size(ampData,1)-1)' / ampFs;
            
            % Make table
            [tb, preTb] = MSessionExplorer.MakeTimeSeriesTable(ampTime, ampData, ...
                'DelimiterTimes', trialStartTime);
            
            % Map trials
            trialMap = se.userData.sessionInfo.intanTrialNum;
            tb = SL.Preprocess.MapTrial(trialMap, tb);
            
            % Save to SE
            se.userData.intanInfo.LFP_table_sample_rate = ampFs;
            se.userData.preTaskData.LFP = preTb;
            se.SetTable('LFP', tb, 'timeSeries');
        end
        
        function Spike2SE(spikeData, se, trialStartTime)
            
            % Make table
            [tb, preTb] = MSessionExplorer.MakeEventTimesTable(spikeData.spike_times, ...
                'DelimiterTimes', trialStartTime, ...
                'VariableNames', arrayfun(@(x) ['unit' num2str(x)], 1:numel(spikeData.spike_times), 'Uni', false));
            
            % Map trials
            trialMap = se.userData.sessionInfo.intanTrialNum;
            tb = SL.Preprocess.MapTrial(trialMap, tb);
            
            % Save to SE
            se.userData.spikeInfo = spikeData.info;
            se.userData.preTaskData.spikeTime = preTb;
            se.SetTable('spikeTime', tb, 'eventTimes');
        end
        
        % Utilties
        function [Lon, Loff] = RemoveArtifactualLicks(bt, tRef)
            % Merge licks with very short inter-lick interval
            
            Lon = bt.lickOn;
            Loff = bt.lickOff;
            
            % Return original columns when there is no lick
            if isnumeric(bt.lickOn) && all(isnan(bt.lickOn))
                return;
            end
            
            % Collect relevant data into a table
            [lo(:,1), lo(:,2)] = ConvertTrial2SessionTime(Lon, tRef);
            lo(:,3) = true;
            
            [lf(:,1), lf(:,2)] = ConvertTrial2SessionTime(Loff, tRef);
            lf(:,3) = false;
            
            tb = array2table([lo; lf], 'VariableNames', {'time', 'trialNum', 'type'});
            tb = sortrows(tb, 'time', 'ascend');
            
            % Remove NaN placeholders
            tb(isnan(tb.time),:) = [];
            
            % Remove partially reported licks
            dType = diff([false; tb.type]);
            isPar = dType==0 & ~isnan(tb.time);
            if any(isPar)
                fprintf('Removed %i partial licks\n', sum(isPar));
                tb(isPar, :) = [];
            end
            
            % Remove very short inter-contact intervals
            dt = diff(tb.time);
            itvl = dt(2:2:end);
            indShort = find(itvl < SL.Param.minILI) * 2;
            tb([indShort; indShort+1], :) = [];
            fprintf('Removed %i intervals less than %gs\n', length(indShort), SL.Param.minILI);
            
            % Convert vectors back to original cell arrays
            I = unique(tb.trialNum(tb.type==1));
            G = findgroups(tb.trialNum(tb.type==1));
            Lon = num2cell(NaN(size(Lon)));
            Lon(I) = splitapply(@(x) {x}, tb.time(tb.type==1), G);
            Lon = cellfun(@(x,r) x-r, Lon, num2cell(tRef), 'Uni', false);
            
            I = unique(tb.trialNum(tb.type==0));
            G = findgroups(tb.trialNum(tb.type==0));
            Loff = num2cell(NaN(size(Loff)));
            Loff(I) = splitapply(@(x) {x}, tb.time(tb.type==0), G);
            Loff = cellfun(@(x,r) x-r, Loff, num2cell(tRef), 'Uni', false);
            
            % Helper function
            function [tSess, trialInd] = ConvertTrial2SessionTime(tTrial, tRef)
                tSess = cellfun(@(x,r) x+r, tTrial, num2cell(tRef), 'Uni', false);
                tSess = cell2mat(tSess);
                trialInd = cellfun(@(n,x) repmat(n,size(x)), num2cell(1:length(tTrial))', tTrial, 'Uni', false);
                trialInd = cell2mat(trialInd);
            end
        end
        
        function result = ComputeDelimiter(sig, fs, varargin)
            % Process signal used for delimiting
            
            % Handle user inputs
            p = inputParser();
            p.addParameter('ValueFunc', @(x) x, @(x) isa(x, 'function_handle'));
            p.parse(varargin{:});
            valFunc = p.Results.ValueFunc;
            
            % Generate timestamps based on sampling rate
            t = (0:numel(sig)-1)' / fs;
            
            % Find rising edges in delimiter signal
            indEdge = MMath.Logical2Bounds(sig); % find pairs of rising and falling edges
            indRise = indEdge(:,1);
            indFall = indEdge(:,2) + 1;
            indFall(end) = min(indFall(end), numel(sig));
            tRise = t(indRise);
            tFall = t(indFall);
            
            % Calculate delimiter values
            dur = tFall - tRise;
            val = valFunc(dur);
            
            % Output
            result.delimiterRiseTime = tRise;
            result.delimiterDur = dur;
            result.delimiterValue = val;
        end
        
        function varargout = MapTrial(ind, varargin)
            % Keep specified rows
            varargout = varargin;
            if isempty(ind)
                return;
            end
            for i = 1 : numel(varargout)
                varargout{i} = varargin{i}(ind,:);
            end
        end
    end
    
end

