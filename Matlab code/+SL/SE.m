classdef SE
    methods(Static)
        % Load se
        function [seArray, filePaths] = LoadSession(varargin)
            % Load session files as MSessionExplorer
            
            % Handle user inputs
            p = inputParser();
            p.addOptional('filePaths', '', @(x) ischar(x) || iscellstr(x) || isempty(x));
            p.addParameter('Enrich', false, @islogical);
            p.addParameter('UserFunc', @(x) x, @(x) isa(x, 'function_handle'));
            p.parse(varargin{:});
            filePaths = p.Results.filePaths;
            isEnrich = p.Results.Enrich;
            userFunc = p.Results.UserFunc;
            
            if isempty(filePaths)
                filePaths = MBrowse.Files();
            else
                filePaths = cellstr(filePaths);
            end
            if isempty(filePaths)
                seArray = [];
                return;
            end
            
            % Preallocation
            seArray(numel(filePaths),1) = MSessionExplorer();
            
            for i = 1 : numel(filePaths)
                [~, fileName, fileExt] = fileparts(filePaths{i});
                disp(['SESSION ' num2str(i) ' - ' fileName]);
                
                if strcmpi(fileExt, '.mat')
                    % MSessionExplorer MAT file
                    load(filePaths{i});
                    
                elseif strcmpi(fileExt, '.txt')
                    % Construct MSessionExplorer object
                    se = MSessionExplorer();
                    
                    % Import SatellitesViewer data
                    satData.file_path = filePaths{i};
                    satData.txt = Satellites.ReadTxt(filePaths{i});
                    SL.Preprocess.SessionInfo2SE(satData, se);
                    SL.Preprocess.Satellites2SE(satData, se);
                end
                
                if isEnrich
                    SL.SE.EnrichAll(se);
                end
                userFunc(se);
                seArray(i) = se;
            end
        end
        
        function xlsTb = AddXlsInfo2SE(seArray, xlsTb)
            % Add metadata found in Excel spreadsheet to userData of SE objects
            
            xlsTb.session_id = cellfun(@(x,y) [x ' ' datestr(y, 'yyyy-mm-dd')], ...
                xlsTb.animal_id, num2cell(xlsTb.date), 'Uni', false);
            
            isRead = [];
            for i = 1 : numel(seArray)
                sId = SL.SE.GetID(seArray(i));
                isHit = strcmp(sId, xlsTb.session_id);
                if ~any(isHit)
                    warning('No entry matches with %s in the spreadsheet.', sId);
                    continue;
                elseif sum(isHit) > 1
                    error('More than one entries match with %s in the spreadsheet.', sId);
                end
                isHit = find(isHit, 1);
                seArray(i).userData.xlsInfo = table2struct(xlsTb(isHit,:));
                isRead(end+1) = isHit;
            end
            xlsTb = xlsTb(isRead,:);
        end
        
        % se utilities
        function [sessionId, animalId] = GetID(varargin)
            % Extract session ID and animal ID, e.g. 'MX210602 2021-06-18', 'MX210602'
            % 
            %   [sessionId, animalId] = SL.SE.GetID(seFileName)
            %   [sessionId, animalId] = SL.SE.GetID(se)
            %   [sessionId, animalId] = SL.SE.GetID(se.userData.sessionInfo)
            %   [sessionId, animalId] = SL.SE.GetID(animalId, sessionDatetime)
            %   [sessionId, animalId] = SL.SE.GetID(animalId, sessionDatetime, subId)
            
            switch numel(varargin)
                case 1
                    var = varargin{1};
                    if isa(var, 'MSessionExplorer')
                        s = var.userData.sessionInfo;
                    elseif isstruct(var)
                        s = var;
                    elseif ischar(var)
                        nameParts = strsplit(var, {' ', '.'});
                        animalId = nameParts{1};
                        sessionId = strjoin(nameParts(1:2), ' ');
                        return
                    else
                        error('The input data type is incorrect');
                    end
                case 2
                    s.animalId = varargin{1};
                    s.sessionDatetime = varargin{2};
                case 3
                    s.animalId = varargin{1};
                    s.sessionDatetime = varargin{2};
                    s.subId = varargin{3};
                otherwise
                    error('Unexpected number of input arguments.');
            end
            
            if ~ischar(s.sessionDatetime)
                s.sessionDatetime = datestr(s.sessionDatetime, 'yyyy-mm-dd');
            end
            if ~isfield(s, 'subId')
                s.subId = '';
            end
            animalId = s.animalId;
            sessionId = [s.animalId ' ' s.sessionDatetime ' ' s.subId];
            sessionId = strtrim(sessionId);
        end
        
        function tb = GetSessionInfoTable(seArray)
            % Summarize key session info in a table
            tb = table();
            for k = numel(seArray) : -1 : 1
                ud = seArray(k).userData;
                tb.animalId{k} = ud.sessionInfo.animalId;
                tb.sessionDatetime(k) = datetime(ud.sessionInfo.sessionDatetime);
                tb.numTrials(k) = seArray(k).numEpochs;
                if isfield(ud, 'spikeInfo')
                    tb.numUnits(k) = numel(ud.spikeInfo.unit_channel_ind);
                else
                    tb.numUnits(k) = NaN;
                end
            end
            tb.sessionDatetime.Format = 'yyyy-MM-dd HH:mm:ss';
        end
        
        function filePaths = UpdateVidFilePath(var)
            % Replace local disk root dir using network root dir
            % e.g. 'F:\old datastore\...' -> '\\OCONNORDATA11\tongue11\SeqLick datastore 1\...'
            % This updates video file paths and makes them accessible from any computer in the lab
            % 
            %   filePaths = SL.SE.UpdateVidFilePath(se)
            %   filePaths = SL.SE.UpdateVidFilePath(filePaths)
            
            % Get old file paths
            if isa(var, 'MSessionExplorer')
                filePaths = var.userData.hsvInfo.filePaths;
            else
                filePaths = cellstr(var);
            end
            
            % Parse and replace
            for i = 1 : numel(filePaths)
                p = filePaths{i}; % e.g. 'F:\SeqLick datastore 1\...'
                pp = strsplit(p, '\');
                pp{1} = SL.Data.rawRootNetwork;
                pp(2) = [];
                p = strjoin(pp, '\'); % e.g. '\\OCONNORDATA11\tongue11\SeqLick datastore 1\...'
                filePaths{i} = p;
            end
            
            if isa(var, 'MSessionExplorer')
                var.userData.hsvInfo.filePaths = filePaths;
            elseif ischar(var)
                filePaths = filePaths{1};
            end
        end
        
        % Enrich se (i.e. add derived data from existing data)
        function EnrichAll(se)
            warning('off', 'backtrace');
            fprintf('Enrich %s\n\n', SL.SE.GetID(se));
            SL.SE.Corrections(se);
            SL.SE.EnrichBehavTables(se);
            SL.SE.EnrichHSV(se);
            SL.SE.EnrichPerch(se);
            SL.SE.EnrichOpto(se);
            SL.SE.AddLickObj(se);
            warning('on', 'backtrace');
        end
        
        function Corrections(se)
            % Correct known errors in data
            
            sessionId = SL.SE.GetID(se);
            [bt, bv] = se.GetTable('behavTime', 'behavValue');
            
            if iscell(bt.opto)
                % MX180202; MX180501 2018-05-01
                warning('%s: some trials contain two opto trigger. Discard the second values (in ITI).', sessionId)
                bt.opto = cellfun(@(x) x(1), bt.opto);
                bv.opto = cellfun(@(x) x(1), bv.opto);
            end
            
            if any(regexp(sessionId, '^MX1802')) && ~all(isnan(bv.opto))
                % All MX1802 sessions
                warning('%s: remove opto trigger data since no opto was actually applied.', sessionId);
                bt.opto(:) = NaN;
                bv.opto(:) = NaN;
            end
            
            if any(~isnan(bt.opto)) && all(isnan(bv.opto))
                % MX1804, MX180803-4. Fixed since 2018/8/8.
                warning('%s: fill missing opto trigger types in value table.', sessionId);
                bv.opto(bt.opto <= bt.cue) = 0;
                bv.opto(bt.opto > bt.cue & bt.opto <= bt.water) = 1;
                bv.opto(bt.opto > bt.water) = 2;
            end
            
            for n = 1 : se.numEpochs
                indRm = bt.posIndex{n} > bt.water(n);
                if any(indRm)
                    % MX180601 since 2018-07-22. MX180803 208-08-17. Fixed since 2018/9/6.
                    warning('%s: remove posIndex events due to user commands after water delivery in epoch %d', ...
                        sessionId, n);
                    bt.posIndex{n}(indRm) = [];
                    bv.posIndex{n}(indRm) = [];
                end
            end
            
            se.SetTable('behavTime', bt);
            se.SetTable('behavValue', bv);
        end
        
        function EnrichBehavTables(se)
            % Add data derived from behavTime and behavValue table
            
            sessionId = SL.SE.GetID(se);
            [bt, bv] = se.GetTable('behavTime', 'behavValue');
            
            % Cue offsets
            bt.cueOff = bt.cue + bv.cue/1000;
            
            % Water related
            bt.waterOff = bt.water + bv.water/1000;
            
            bt.waterTrig = NaN(size(bt.water));
            bv.waterDelay = NaN(size(bt.water));
            bt.endConsump = NaN(size(bt.water));
            for n = 1 : se.numEpochs
                % Cache variables
                tEndDr = bt.posIndex{n}(end);
                tLick = bt.lickOn{n};
                
                % Time of reward triggering lick and delay of water delivery
                idx = find(tLick >= tEndDr + 0.08, 1);
                if ~isempty(idx)
                    bt.waterTrig(n) = tLick(idx);
                    bv.waterDelay(n) =  (bt.water(n) - tLick(idx)) * 1000;
                end
                
                % Last consumatory lick
                idx = find(tLick > bt.waterOff(n) & diff([tLick; Inf]) > 1, 1);
                if ~isempty(idx)
                    bt.endConsump(n) = tLick(idx);
                end
            end
            
            % Create categorical sequence ID
            % MX180804 2018-08-30: last trial has extra posIndex
            seqId = cell(se.numEpochs, 1);
            for n = 1 : se.numEpochs
                if isnan(bv.posIndex{n})
                    % MX180602 2018-07-03: trial 267
                    % MX180701 2018-08-29: trial 159; MX180701 2018-09-10: trial 108
                    % MX181002 2018-09-15: trial 1
                    % MX181101 2019-01-26: trial 252
                    warning('%s: trial %d might be aborted as there is no sequence info.', sessionId, n);
                    seqId{n} = 'none';
                else
                    seqId{n} = arrayfun(@int2str, bv.posIndex{n})';
                end
            end
            bv.seqId = SL.Param.CategorizeSeqId(seqId);
            
            se.SetTable('behavTime', bt);
            se.SetTable('behavValue', bv);
        end
        
        function EnrichPerch(se)
            % Add data derived from Perch signals
            
            if ~ismember('adc', se.tableNames)
                return;
            end
            
            % Filtering
            lp = se.GetColumn('adc', {'lickportV', 'lickportH'});
            se.SetColumn('adc', {'forceV', 'forceH', 'vibV', 'vibH'}, [lp lp]);
            
            Fs = 1e3;%se.userData.intanInfo.adc_table_sample_rate;
            
            se.SetColumn('adc', {'forceV', 'forceH'}, ...
                @(x) SL.Perch.FiltLick(x, Fs), 'all');
            
            se.SetColumn('adc', {'vibV', 'vibH'}, ...
                @(x) SL.Perch.FiltVibration(x, Fs), 'all');
            
            % Compute touch force
            [bt, adc] = se.GetTable('behavTime', 'adc');
            for i = 1 : se.numEpochs
                % Find mask of touch
                tOn = bt.lickOn{i} - 0.005;
                tOff = bt.lickOff{i} + 0.005;
                t = adc.time{i};
                isTouch = any(t >= tOn' & t <= tOff', 2);
                
                % Interpolate baseline during touches
                sig = [adc.forceV{i} adc.forceH{i}];
                base = sig;
                base(isTouch,:) = NaN;
                base = fillmissing(base, 'linear');
                
                % Add force to adc table and Lick objects
                sig = SL.Perch.Volt2Newton(sig - base);
                adc.forceV{i} = sig(:,1);
                adc.forceH{i} = sig(:,2);
            end
            se.SetTable('adc', adc);
            
            %{
            figure(123); clf
            ind = 1:5;
            MPlot.PlotTraceLadder(adc.time(ind), adc.forceV(ind), ind, 'Scalar', 3, 'Color', 'r'); hold on
            MPlot.PlotTraceLadder(adc.time(ind), adc.forceV(ind), ind, 'Scalar', 3, 'Color', 'b');
            MPlot.PlotRaster(bt.lickOn(ind), ind, .6, 'Color', 'r');
            MPlot.PlotRaster(bt.lickOff(ind), ind, .6, 'Color', 'b');
            xlim([0 3])
            %}
        end
        
        function EnrichOpto(se)
            % Add data derived from opto channels
            
            % Add default values
            colNames = {'optoDur1', 'optoDur2', 'optoFreq1', 'optoFreq2', 'optoMod1', 'optoMod2'};
            colDefaults = NaN(se.numEpochs, numel(colNames));
            se.SetColumn('behavValue', colNames, colDefaults);
            
            % Get data
            if ~ismember('adc', se.tableNames)
                return;
            end
            [bv, adc] = se.GetTable('behavValue', 'adc');
            
            % 
            if ismember('opto1', adc.Properties.VariableNames)
                [bv.optoDur1, bv.optoFreq1, bv.optoMod1] = ...
                    cellfun(@(t,s) SL.Opto.AnalyzeWaveform(t,s,SL.Param.vOptoAdcThreshold), ...
                    adc.time, adc.opto1);
                
                bv.optoDur1 = round(bv.optoDur1, 2);
                bv.optoFreq1 = round(bv.optoFreq1);
                bv.optoMod1 = MMath.Bound(bv.optoMod1 / SL.Param.vOptoAdcPerMod / 5, [2.^-(0:5), 0]);
            end
            
            if ismember('opto2', adc.Properties.VariableNames)
                [bv.optoDur2, bv.optoFreq2, bv.optoMod2] = ...
                    cellfun(@(t,s) SL.Opto.AnalyzeWaveform(t,s,SL.Param.vOptoAdcThreshold), ...
                    adc.time, adc.opto2);
                
                bv.optoDur2 = round(bv.optoDur2, 2);
                bv.optoFreq2 = round(bv.optoFreq2);
                bv.optoMod2 = MMath.Bound(bv.optoMod2 / SL.Param.vOptoAdcPerMod / 5, [2.^-(0:5), 0]);
            end
            
            se.SetTable('behavValue', bv);
            
            %{
            figure(123); clf
            ind = 1:5;
            MPlot.PlotTraceLadder(adc.time(ind), adc.opto1(ind), ind, 'Scalar', 1, 'Color', 'r'); hold on
            MPlot.PlotTraceLadder(adc.time(ind), adc.opto2(ind), ind, 'Scalar', 1, 'Color', 'b');
            xlim([0 3])
            %}
        end
        
        function EnrichHSV(se)
            % Add data derived from hsv table
            
            % Get hsv table
            if ~ismember('hsv', se.tableNames)
                return;
            end
            hsv = se.GetTable('hsv');
            
            % Fix errors in data
            sessionId = SL.SE.GetID(se);
            if ismember(se.userData.sessionInfo.animalId, {'MX170903', 'MX180201'}) && hsv.time{1}(1) == 0
                % All sessions of MX170903 and MX180201
                warning('%s: add manually curated trigger delay to HSV time.', sessionId);
                xlsTb = MUtil.ReadXls([sessionId ' video delay.xlsx'], 1, 'ReadVariableNames', false);
                tShift = xlsTb.(1);
                tShift(tShift==0) = median(tShift);
                hsv.time = cellfun(@(x,y) x+y, hsv.time, num2cell(tShift), 'Uni' ,false);
            end
            
            % Convert landmark coordinates to length and angle
            C = hsv.tongue_bottom_lm;
            L = cell(size(C));
            A = cell(size(C));
            dL = cell(size(C));
            for i = 1 : se.numEpochs
                [L{i}, A{i}, dL{i}] = SL.HSV.Landmarks2Kinematics(C{i});
                A{i} = SL.HSV.RmAngOutliers(A{i});
            end
            
            % Add to hsv table
            hsv.tongue_bottom_length = L;
            hsv.tongue_bottom_angle = A;
            hsv.tongue_bottom_velocity = dL;
            se.SetTable('hsv', hsv);
        end
        
        function AddLickObj(se)
            % Construct Lick objects
            
            % Get table
            if ~ismember('hsv', se.tableNames)
                return;
            end
            [bt, bv, hsv] = se.GetTable('behavTime', 'behavValue', 'hsv');
            if ismember('adc', se.tableNames)
                adc = se.GetTable('adc');
            end
            
            for i = 1 : se.numEpochs
                % Construct Lick objects
                lickObj = SL.Lick(bt.lickOn{i}, bt.lickOff{i}, hsv.time{i}, hsv.is_tongue_out{i});
                
                % Label licks with position ID and other markers
                lickObj = lickObj.ResolvePositionInfo(bt.posIndex{i}, bv.posIndex{i});
                
                % Add HSV data
                lickObj = lickObj.AddHSV( ...
                    hsv.time{i},...
                    hsv.tongue_bottom_lm{i}, ...
                    hsv.tongue_bottom_length{i}, ...
                    hsv.tongue_bottom_angle{i});
                
                % Add Perch data
                if exist('adc', 'var')
                    lickObj = lickObj.AddADC(adc.time{i}, adc.forceV{i}, adc.forceH{i});
                end
                
                bt.lickObj{i} = lickObj;
            end
            
%             bt.lickObj = cellfun(@SL.Lick, ...
%                 bt.lickOn, bt.lickOff, hsv.time, hsv.is_tongue_out, 'Uni', false);
%             
%             bt.lickObj = cellfun(@ResolvePositionInfo, ...
%                 bt.lickObj, bt.posIndex, bv.posIndex, 'Uni', false);
%             
%             bt.lickObj = cellfun(@AddHSV, ...
%                 bt.lickObj, ...
%                 hsv.time, ...
%                 hsv.tongue_bottom_lm, ...
%                 hsv.tongue_bottom_length, ...
%                 hsv.tongue_bottom_angle, ...
%                 'Uni', false);
%             
%             if ismember('adc', se.tableNames)
%                 adc = se.GetTable('adc');
%                 
%                 bt.lickObj = cellfun(@AddADC, ...
%                     bt.lickObj, ...
%                     adc.time, ...
%                     adc.forceV, ...
%                     adc.forceH, ...
%                     'Uni', false);
%             end
            
            % Add derived events to behavTime table
            airLickObj = cellfun(@(x) x(~x.IsTouch), bt.lickObj, 'Uni', false);
            bt.airOn = cellfun(@(x) x.GetTfield('tOut'), airLickObj, 'Uni', false);
            bt.airOff = cellfun(@(x) x.GetTfield('tIn'), airLickObj, 'Uni', false);
            
            se.SetTable('behavTime', bt);
        end
        
        function AddPositionalCommands(se)
            % 
            
            % Convert text string to lines, including output commands
            txtLines = Satellites.StringToLines(se.userData.satInfo.txt);
            
            % Parse out event parts
            [~, ~, eventParts] = Satellites.LineParts(txtLines);
            
            % Delimit events into trials
            epochs = Satellites.GroupEventsByTime(eventParts, 'trialNum');
            
            % Find command values for each trial
            cmdList = {'REF', 'PosA', 'PosRR'};
            cmdVals = cell(numel(epochs)-1, numel(cmdList));
            currentVals = {NaN(1,2), NaN(1,7), NaN};
            for i = 1 : size(cmdVals,1)
                cmdNames = cellfun(@(x) x(1), epochs{i});
                for j = 1 : size(cmdVals,2)
                    cmdInd = strcmp(cmdNames, cmdList{j});
                    cmdInd = find(cmdInd, 1, 'last'); % use the last command in a trial
                    if ~isempty(cmdInd)
                        % Get the updated values
                        val = str2double(epochs{i}{cmdInd}(2:end));
                        currentVals{j} = val;
                        cmdVals{i,j} = val;
                    else
                        % Persist values
                        cmdVals{i,j} = currentVals{j};
                    end
                end
            end
            
            % Add to table
            bv = se.GetTable('behavValue');
            for i = 1 : numel(cmdList)
                val = cell2mat(cmdVals(:,i));
                if any(isnan(val(:)))
                    warning('%s: %s contains NaN. The command was not issued before the session', ...
                        SL.SE.GetID(se), cmdList{i});
                end
                bv.(cmdList{i}) = val;
            end
            
            % Derive coordinate of the most lateral position
            bv.distX = bv.PosRR;
            bv.distY = abs(bv.PosRR .* sind(bv.PosA(:,1)-bv.PosA(:,4)));
            
            se.SetTable('behavValue', bv);
        end
        
        % seTb
        function seTb = Transform(se, ops)
            % Process se for specific analyses base on parameters in ops
            
            se.isVerbose = false;
            se.userData.ops = ops;
            
            % Add spikeRate table to SE
            if ops.isSpkRate
                disp('Compute spike rates');
                SL.Unit.AddSpikeRateTable(se, ops);
            end
            
            % Morph time so that lick bouts have the same inter-lick-intervals
            if ops.isMorph
                disp('Morph time');
                SL.Morpher.MorphSE(se, ops);
            end
            
            % Reslice session to include a pre-trial period
            if ops.tReslice
                disp('Reslice session');
                se.SliceSession(ops.tReslice, 'relative');
            end
            
            % Exclude unwanted trials
            disp('Exclude trials');
            SL.Behav.ExcludeTrials(se, ops);
            
            % Center the range of lick angle
            if ops.isStdLickRange
                SL.Behav.StandardizeLickRange(se);
            end
            
            % Align trial time to certain event
            if ~isempty(ops.alignType)
                disp('Align time');
                SL.Match.AlignTime(se, ops);
            end
            
            % Split data by experiment conditions
            disp('Split data by conditions');
            seTb = SL.SE.SplitConditions(se, ops);
            
            % Match trials with similar behavior
            if ops.isMatch
                disp('Match trials');
                for k = 1 : height(seTb)
                    seTb.se(k) = SL.Match.MatchTrials(seTb.se(k), ops);
                    seTb.numMatched(k) = seTb.se(k).numEpochs;
                end
            end
        end
        
        function seTb = SplitConditions(se, ops)
            % Split an SE into a table of SEs by conditions in the behavValue table
            % Trials with NaN condition will be excluded except for opto
            
            % Find groups
            if isempty(ops.conditionVars)
                % Initialize table with a dummy grouping variable
                dummyCond = ones(se.numEpochs, 1);
                T = table(dummyCond);
            else
                % Get and modify variables from behavValue table
                bv = se.GetTable('behavValue');
                bv.opto(isnan(bv.opto)) = -1;
                bv.seqId = SL.Param.CategorizeSeqId(bv.seqId);
                se.SetTable('behavValue', bv);
                T = bv(:,ops.conditionVars);
            end
            [condId, seTb] = findgroups(T);
            
            % Split SE by conditions
            for i = 1 : max(condId)
                % Remove non-member
                seCopy = se.Duplicate();
                seCopy.RemoveEpochs(condId ~= i);
                
                % Add to table
                seTb.animalId{i} = seCopy.userData.sessionInfo.animalId;
                seTb.sessionId{i} = SL.SE.GetID(seCopy);
                seTb.se(i) = seCopy;
                seTb.numTrial(i) = seCopy.numEpochs;
            end
        end
        
        function condTb = CombineConditions(condTb, seTb, varargin)
            % Combine the same conditions across rows of an (usually concatenated) seTb
            
            p = inputParser;
            p.addParameter('UniformOutput', false);
            p.parse(varargin{:});
            isUni = p.Results.UniformOutput;
            
            % Take out condition columns in seTb
            isCond = ismember(seTb.Properties.VariableNames, condTb.Properties.VariableNames);
            seCond = seTb(:,isCond);
            seTb = seTb(:,~isCond);
            
            % Process each row of condTb
            nCond = width(condTb);
            for i = 1 : height(condTb)
                % Find the same condition across sessions
                isCond = true(height(seTb),1);
                for j = 1 : nCond
                    isCond = isCond & ismember(seCond.(j), condTb.(j)(i));
                end
                if ~any(isCond)
                    continue;
                end
                
                % Concatenate data
                for j = 1 : width(seTb)
                    vn = seTb.Properties.VariableNames{j};
                    col = seTb.(vn);
                    if iscell(col)
                        s2 = cellfun(@(x) size(x,2), col);
                        isCatable = numel(unique(s2)) == 1;
                        if ~iscellstr(col) && isCatable
                            condTb.(vn){i} = cat(1, col{isCond});
                            continue
                        end
                    end
                    condTb.(vn){i} = col(isCond);
                end
            end
            
            % Remove empty conditions
            condTb(cellfun(@isempty, condTb.(nCond+1)), :) = [];
            
            % Denest
            if ~isUni
                return;
            end
            for j = nCond+1 : width(condTb)
                try
                    condTb.(j) = cat(1, condTb.(j){:});
                catch
                    warning('Column %s cannot be denested', condTb.Properties.VariableNames{j});
                end
            end
        end
        
        function seTb = SetStimRespArrays(seTb, ops)
            % Set stim and resp matrices for each se in seTb
            for k = 1 : height(seTb)
                se = seTb.se(k);
                [stim, t] = SL.SE.GetStimArray(se, ops);
                resp = SL.SE.GetRespArray(se, ops);
                seTb.time{k} = t;
                seTb.stim{k} = stim;
                seTb.resp{k} = resp;
            end
        end
        
        function [stim, t, varNames] = GetStimArray(se, ops)
            % Resample behavioral variables to form a time-by-variable-by-trial array
            % 
            % ops.hsvVars, ops.adcVars, ops.valVars, ops.derivedVars
            %   Variables to extract and resample. ops.isFillVel, ops.isFillLen and ops.isFillAng 
            %   control whether or not to fill missing values for respective hsv variables
            %   
            % ops.rsWin, ops.rsBinSize, ops.rsArgs
            %   Time window, bin size, and interpolation parameters for resampling
            % 
            % ops.dimAverage and ops.dimCombine
            %   Determine what dimensions to collapse or vectorize
            % 
            
            % Parameters
            varNames = SL.Param.GetAllResampleVars(ops);
            tEdges = ops.rsWin(1) : ops.rsBinSize : ops.rsWin(2);
            rsArgs = ops.rsArgs;
            
            % Initialize an empty table
            stimTb = table();
            
            % Resample data in hsv table
            if ~isempty(ops.hsvVars) && ismember('hsv', se.tableNames)
                hsv = se.GetTable('hsv');
                for i = 1 : height(hsv)
                    hsv.tongue_bottom_velocity{i} = gradient(hsv.tongue_bottom_length{i}, 1/400);
                    if ops.isFillVel
                        hsv.tongue_bottom_velocity{i} = fillmissing(hsv.tongue_bottom_velocity{i}, 'nearest');
                    end
                    
                    if ops.isFillLen
                        hsv.tongue_bottom_length{i} = fillmissing(hsv.tongue_bottom_length{i}, 'constant', 0);
                    end
                    
                    hsv.tongue_bottom_angle{i}(hsv.tongue_bottom_length{i} < SL.Param.minLen4Ang) = NaN;
                    if ops.isFillAng
                        hsv.tongue_bottom_angle{i} = fillmissing(hsv.tongue_bottom_angle{i}, 'nearest');
                    end
                end
                hsv = se.ResampleTimeSeries(hsv, tEdges, [], ops.hsvVars, rsArgs{:});
                stimTb = [stimTb hsv(:,2:end)];
            end
            
            % Resample data in adc table
            if ~isempty(ops.adcVars) && ismember('adc', se.tableNames)
                adc = se.GetTable('adc');
                adc.timeVar = adc.time;
                for i = 1 : height(adc)
                    adc.force{i} = hypot(adc.forceV{i}, adc.forceH{i});
                end
                adc = se.ResampleTimeSeries(adc, tEdges, [], ops.adcVars, rsArgs{:});
                stimTb = [stimTb adc(:,2:end)];
            end
            
            % Expand behavValue data to fit resampled time series
            if ~isempty(ops.valVars) && ismember('behavValue', se.tableNames)
                bv = se.GetTable('behavValue');
                bv = bv(:, ops.valVars);
                nSp = length(tEdges) - 1;
                for i = 1 : width(bv)
                    bv.(i) = arrayfun(@(x) repmat(x, [nSp 1]), bv.(i), 'Uni', false);
                end
                stimTb = [stimTb bv];
            end
            
            % Resample port positions to "progress"
            if ismember('posUni', ops.derivedVars)
                isInvert = true;
                isMono = false;
                stimTb.posUni = SL.Behav.ResamplePosition(se, tEdges, isInvert, isMono);
            end
            if ismember('posUniMono', ops.derivedVars)
                isInvert = true;
                isMono = true;
                stimTb.posUniMono = SL.Behav.ResamplePosition(se, tEdges, isInvert, isMono);
            end
            
            % Flag for backtracking or non-backtracking trial
            if ismember('isBacktrack', ops.derivedVars)
                seqId = se.GetColumn('behavValue', 'seqId');
                isBacktrack = NaN(size(seqId));
                isBacktrack(ismember(seqId, [SL.Param.stdSeqs, SL.Param.zzSeqs])) = 0;
                isBacktrack(ismember(seqId, SL.Param.backSeqs)) = 1;
                nSp = length(tEdges) - 1;
                stimTb.isBacktrack = arrayfun(@(x) repmat(x, [nSp 1]), isBacktrack, 'Uni', false);
            end
            
            % Target angle
            if ismember('theta_shoot', ops.derivedVars)
                ts = table;
                lickObj = se.GetColumn('behavTime', 'lickObj');
                [ts.theta_shoot, ~, ts.time] = cellfun(@(x) x(x.IsTracked).ShootingAngle, lickObj, 'Uni', false);
                ts = movevars(ts, 'time', 'Before', 'theta_shoot');
                ts = se.ResampleTimeSeries(ts, tEdges, 'linear', 0);
                stimTb.theta_shoot = ts.theta_shoot;
            end
            
            
            % Convert table to array
            stim = cell(1, width(stimTb));
            for i = 1 : width(stimTb)
                stim{i} = double(cat(3, stimTb.(i){:})); % cat trials along 3rd dim
            end
            stim = cat(2, stim{:}); % cat vars along 2nd dim
            
            % Make timestamp array
            tCenters = tEdges(1:end-1) + diff(tEdges) / 2;
            t = repmat(tCenters', [1 1 se.numEpochs]);
            
            % Averaging and combining dimensions
            if ops.dimAverage
                t = mean(t, ops.dimAverage);
                stim = mean(stim, ops.dimAverage, 'omitnan');
                t = MMath.SqueezeDims(t, ops.dimAverage);
                stim = MMath.SqueezeDims(stim, ops.dimAverage);
            end
            if ops.dimCombine
                t = MMath.CombineDims(t, ops.dimCombine);
                stim = MMath.CombineDims(stim, ops.dimCombine);
            end
        end
        
        function [resp, t] = GetRespArray(se, ops)
            % Resample spike rates to form a time-by-unit-by-trial matrix
            
            % Parameters
            tEdges = ops.rsWin(1) : ops.rsBinSize : ops.rsWin(2);
            rsArgs = {'Method', 'nearest', 'Extrap', 'nearest'};
            
            % Resample spikeRate data
            respTb = se.ResampleTimeSeries('spikeRate', tEdges, rsArgs{:});
            
            % Convert table to matrix
            resp = cell(1, width(respTb));
            for i = 1 : width(respTb)
                resp{i} = double(cat(3, respTb.(i){:})); % cat trials along 3rd dim
            end
            t = resp{1};
            resp = cat(2, resp{2:end}); % cat units along 2nd dim
            
            % Averaging and combining dimensions
            if ops.dimAverage
                t = mean(t, ops.dimAverage);
                resp = mean(resp, ops.dimAverage, 'omitnan');
                t = MMath.SqueezeDims(t, ops.dimAverage);
                resp = MMath.SqueezeDims(resp, ops.dimAverage);
            end
            if ops.dimCombine
                t = MMath.CombineDims(t, ops.dimCombine);
                resp = MMath.CombineDims(resp, ops.dimCombine);
            end
        end
        
        function seTb = SetMeanArrays(seTb, var4mean)
            % Average stim, resp and projection matrices across trials
            % The size of a mean matrix is time-by-var-by-5(mean,sd,ciLow,ciHigh,rNaN)
            % where rNaN indicates the fraction of missing observation
            if nargin < 2
                var4mean = {'time', 'stim', 'resp', 'reg', 'pca'};
            end
            tbVars = seTb.Properties.VariableNames;
            for i = 1 : height(seTb)
                N = sum(seTb.numMatched{i});
                for j = 1 : numel(var4mean)
                    vn = var4mean{j};
                    if ~ismember(vn, tbVars) || ~isnumeric(seTb.(vn){i})
                        continue;
                    end
                    seTb.(vn){i} = compute(seTb.(vn){i}, N);
                end
                seTb.time{i} = seTb.time{i}(:,1,1);
            end
            function M = compute(X, nTrial)
                nTime = size(X,1) / nTrial;
                nVar = size(X,2);
                X = reshape(X, [nTime nTrial nVar]);
                X = permute(X, [1 3 2]);
                [m, sd, ~, ci] = MMath.MeanStats(X, 3, 'IsOutlierArgs', {'median'}, ...
                    'NBoot', 2000, 'Alpha', 0.01, 'Options', statset('UseParallel', true));
                rNaN = mean(isnan(X), 3);
                M = cat(3, m, sd, ci, rNaN);
            end
        end
        
        function seArray = PartitionTrials(se, k)
            % Randomly split trials into partitions
            %   k is the number of fold as in KFold crossvalidation
            %   se can be an array and the partition populates the second dimension
            
            if numel(se) == 1
                % Partition
                c = cvpartition(se.numEpochs, 'Kfold', k);
                for i = k : -1 : 1
                    seArray(i) = se.Duplicate();
                    seArray(i).RemoveEpochs(~c.test(i));
                end
            else
                % Recursively process each se
                for i = numel(se) : -1 : 1
                    seArray(i,:) = SL.SE.PartitionTrials(se(i), k);
                end
            end
        end
    end
end

