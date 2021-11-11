classdef MP
    methods(Static)
        function Video(ax, se)
            
            if isfield(se.userData, 'cameraInfo')
                atb = se.userData.cameraInfo.alignTb;
            else
                return;
            end
            
            tr = ax.UserData.trialNum;
            t = ax.UserData.time;
            if tr > height(atb) || tr < 1
                return;
            end
            
            % Initialize image object (must be done before initializing overlaying objects)
            if ~isfield(ax.UserData, 'img') || isempty(ax.UserData.img) || ~ishandle(ax.UserData.img)
                ax.UserData.img = imagesc(ax, zeros(1024, 1280));
                ax.CLim = [0 255];
                colormap(ax, 'gray');
                axis(ax, 'image');
                ax.XAxis.Visible = 'off';
                ax.YAxis.Visible = 'off';
                ax.TickLength(1) = 0;
                hold(ax, 'on');
            end
            
            % Find video file
            vidPath = [atb.vidNames{tr} '.avi'];
            if ~exist(vidPath, 'file')
                return;
            end
            
            if ~isfield(ax.UserData, 'vidObj')
                % Load the first video file
                ax.UserData.vidObj = VideoReader(vidPath);
                title(ax, ax.UserData.vidObj.Name, 'Interpreter', 'none');
                ax.TitleFontSizeMultiplier = 1.2;
            end
            vidObj = ax.UserData.vidObj;
            if ~strcmp(vidObj.Name, vidPath)
                % Load a new video file
                delete(vidObj);
                vidObj = VideoReader(vidPath);
                ax.UserData.vidObj = vidObj;
                title(ax, vidObj.Name, 'Interpreter', 'none');
                ax.TitleFontSizeMultiplier = 1.2;
            end
            
            % Find video time
            t = interp1(atb.tIntan{tr}, atb.tLed{tr}, t, 'linear', 'extrap');
            
            % Read video frame
            if t < 0 || t > vidObj.Duration
                return;
            end
            vidObj.CurrentTime = t;
            fr = rgb2gray(readFrame(vidObj));
            
            % Update plot
            ax.UserData.img.CData = fr;
        end
        
        function State(ax, se)
            
            if ~ismember('state', se.tableNames)
                return;
            end
            t0 = ax.UserData.time;
            z = 2^(-ax.UserData.zoom);
            tWin = t0 + 4 * [-z z];
            
            % Slice signals
            tb = se.SliceTimeSeries('state', tWin, 1, 'Fill', 'bleed');
            t = tb.time{1};
            s = tb.state{1};
            w = [-1 1];
            cc = lines(6);
            
            % Update plot
            cla(ax);
            hold(ax, 'on');
            plotRibbon(ax, s, w, cc, t, 1:6);
            ax.XLim = tWin;
            ax.YLim = w;
            ax.XLabel.String = 'Time (s)';
            ax.TickDir = 'out';
            ax.YAxis.Visible = 'off';
            
            plot(ax, [t0 t0]', ax.YLim', 'LineWidth', 2, 'Color', [0 0 0 .2])
            
            function plotRibbon(ax, xRange, yRange, colors, indVal, groups)
                
                % Standardize ranges
                xRange = findRange(xRange, groups, indVal);
                yRange = repmat({yRange(:)'}, size(xRange));
                
                function r = findRange(r, g, iv)
                    % Find ranges indices from a vector of discrete values
                    r = MMath.ValueBounds(r, g, 'Uni', false);
                    for k = 1 : numel(r)
                        r{k} = r{k} + [-.5 .5];
                    end
                    if ~isempty(iv)
                        % Convert indices to axis values
                        iv = iv(:);
                        ind = (1:numel(iv))';
                        for k = 1 : numel(r)
                            r{k} = interp1(ind, iv, r{k}, 'linear', 'extrap');
                        end
                    end
                end
                
                % Plot the ribbon
                for i = 1 : numel(xRange)
                    MPlot.Blocks(xRange{i}, yRange{i}, colors(i,:), 'Parent', ax);
                end
            end
        end
        
        function LFP(ax, se)
            if ~ismember('LFP', se.tableNames)
                return;
            end
            t0 = ax.UserData.time;
            z = 2^(-ax.UserData.zoom);
            tWin = t0 + 4 * [-z z];
            
            % Slice signals
            tb = se.SliceTimeSeries('LFP', tWin, 1, 'Fill', 'bleed');
            t = tb.time{1};
            v = tb.series1{1};
            
            % Update plot
            cla(ax);
            plot(ax, t, v, 'k');
            ax.XLim = tWin;
            ax.YLim = [-1 1] * 2e3;
            ax.XLabel.String = 'Time (s)';
            ax.TickLength = [0 0];
            ax.Box = 'off';
            grid(ax, 'on');
            
            hold(ax, 'on');
            plot(ax, [t0 t0]', ax.YLim', 'LineWidth', 2, 'Color', [0 0 0 .2])
        end
        
        function Spectrum1D(ax, se)
            
            if ~ismember('LFP', se.tableNames)
                return;
            end
            t0 = ax.UserData.time;
            z = 2^(-ax.UserData.zoom);
            tWin = t0 + 4 * [-z z];
            
            % Slice signals
            tb = se.SliceTimeSeries('LFP', tWin, 1, 'Fill', 'bleed');
            t = tb.time{1};
            v = tb.series1{1};
            
            % Transform signal
            fLims = [0 30];
            [P, F] = pspectrum(v, t, 'FrequencyLimits', fLims);
            
            % Plot
            plot(ax, F, P, 'k');
            ax.XLabel.String = 'Frequency (Hz)';
            ax.YLabel.String = 'Power';
            ax.TickDir = 'out';
        end
        
        function Spectrum2D(ax, se)
            
            if ~ismember('LFP', se.tableNames)
                return;
            end
            t0 = ax.UserData.time;
            z = 2^(-ax.UserData.zoom);
            tWin = t0 + 4 * [-z z];
            
            % Slice signals
            tb = se.SliceTimeSeries('LFP', tWin, 1, 'Fill', 'bleed');
            t = tb.time{1};
            v = tb.series1{1};
            
            % Transform signal
            fLims = [0 30];
            [P, F, T] = pspectrum(v, t, ...
                'spectrogram', ...
                'FrequencyLimits', fLims, ...
                'TimeResolution', 1.5, ...
                'OverlapPercent', 50);
            P = P.^(1/2);
            
            % Plot
            imagesc(ax, T, F, P);
            colormap(ax, 'bone');
            ax.CLim = [0 100];
            ax.XLim = tWin;
            ax.YLim = fLims;
            ax.XLabel.String = 'Time (s)';
            ax.YLabel.String = 'Frequency (Hz)';
            ax.YDir = 'normal';
            ax.TickDir = 'out';
        end
        
        function SpikeRaster(ax, se)
            
            k = ax.UserData.trialNum;
            if k > se.numEpochs || k < 1
                return;
            end
            if ~ismember('spikeTime', se.tableNames)
                return;
            end
            
            % Process spike times
            tb = se.SliceEventTimes('spikeTime', ax.UserData.timeLimits, k, 'Fill', 'bleed');
            [spkTimes, spkY, yTick] = SL.BehavFig.ConvertEventTimesForRasters(tb{1,:});
            
            % Update plot
            cla(ax);
            MPlot.PlotPointAsLine(spkTimes, spkY, .6, 'Color', [0 0 0], 'Parent', ax);
            hold(ax, 'on');
            
            ax.YTick = yTick;
            ax.XLabel.String = 'Time (s)';
            ax.YLabel.String = 'Unit';
            ax.TickLength = [0 0];
            ax.YGrid = 'on';
            ax.YLim = [0 width(tb)+1];
            
            % Callback
            ax.ButtonDownFcn = {@SL.MP.UnitPlots, se};
        end
        
        function isHit = ChangeState(d, se)
            
            % Process callback data
            modName = d.eventdata.Modifier;
            keyName = d.eventdata.Key;
            t0 = d.time;
            switch keyName
                case {'1', '2', '3', '4', '5', '6'}
                    val = str2double(keyName);
                case 'backquote'
                    val = 0;
                otherwise
                    isHit = false;
                    return
            end
            
            % Locate episode
            rt = se.GetReferenceTime();
            ep = find(t0 > rt, 1, 'last');
            stb = se.GetTable('state');
            t = stb.time{ep} + rt(ep);
            s = stb.state{ep};
            
            % Find range
            ids = find(diff([0; s]));
            [~, i0] = min(abs(t0 - t));
            ids1 = find(ids <= i0, 1, 'last');
            ids2 = find(ids >= i0, 1);
            
            if isempty(ids)
                % No transition labeled
                i1 = i0;
                i2 = i0;
            elseif ~isempty(ids1)
                % Has transition before
                i1 = ids(ids1);
                i2 = i0;
            else
                % Only has transition after
                i1 = i0;
                i2 = ids(ids2);
            end
            
            % Set state
            s(i1:i2) = val;
            stb.state{ep} = s;
            se.SetTable('state', stb);
            
            isHit = true;
        end
    end
end


