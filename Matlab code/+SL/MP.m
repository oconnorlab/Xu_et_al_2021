classdef MP
    methods(Static)
        function Video(ax, se)
            
            tr = ax.UserData.trialNum;
            t = ax.UserData.time;
            if tr > se.numEpochs || tr < 1
                return;
            end
            
            if isfield(se.userData, 'hsvInfo')
                vidFilePaths = se.userData.hsvInfo.filePaths;
            else
                return;
            end
            
            % Initialize image object (must be done before initializing overlaying objects)
            if ~isfield(ax.UserData, 'img') || isempty(ax.UserData.img) || ~ishandle(ax.UserData.img)
                ax.UserData.img = imagesc(ax, zeros(320, 800));
                ax.CLim = [0 255];
                colormap(ax, 'gray');
                axis(ax, 'image');
                ax.XAxis.Visible = 'off';
                ax.YAxis.Visible = 'off';
                ax.TickLength(1) = 0;
                hold(ax, 'on');
            end
            
            % Find video file
            fileIdx = se.epochInd(tr);
            vidFilePath = SL.SE.UpdateVidFilePath(vidFilePaths{fileIdx});
            if ~exist(vidFilePath, 'file')
                return;
            end
            
            if ~isfield(ax.UserData, 'vidObj')
                % Load the first video file
                ax.UserData.vidObj = VideoReader(vidFilePath);
                title(ax, ax.UserData.vidObj.Name, 'Interpreter', 'none');
                ax.TitleFontSizeMultiplier = 1.2;
            end
            vidObj = ax.UserData.vidObj;
            if ~strcmp(fullfile(vidObj.Path, vidObj.Name), vidFilePath)
                % Load a new video file
                delete(vidObj);
                vidObj = VideoReader(vidFilePath);
                ax.UserData.vidObj = vidObj;
                title(ax, vidObj.Name, 'Interpreter', 'none');
                ax.TitleFontSizeMultiplier = 1.2;
            end
            
            % Find video time
            hsv = se.GetTable('hsv');
            t = t - hsv.time{tr}(1);
            
            % Read video frame
            if t < 0 || t > vidObj.Duration
                return;
            end
            vidObj.CurrentTime = t;
            fr = rgb2gray(readFrame(vidObj));
            
            % Update plot
            ax.UserData.img.CData = fr;
        end
        
        function TrackingOnVideo(ax, se)
            
            tr = ax.UserData.trialNum;
            t = ax.UserData.time;
            if tr > se.numEpochs || tr < 1
                return;
            end
            if ~ismember('hsv', se.tableNames)
                return;
            end
            
            % Read landmark
            tb = se.GetTable('hsv');
            ts = tb.time{tr};
            [~, idx] = min(abs(ts - t));
            lm = tb.tongue_bottom_lm{tr}(idx,:);
            [lmX, lmY] = transformPointsInverse(se.userData.hsvInfo.tform, lm(1:2)', lm(3:4)');
            
            % Update plot
            if isfield(ax.UserData, 'lm') && ~isempty(ax.UserData.lm) && ishandle(ax.UserData.lm)
                ax.UserData.lm.XData = lmX;
                ax.UserData.lm.YData = lmY;
            else
                ax.UserData.lm = plot(ax, lmX, lmY, 'r*');
                hold(ax, 'on');
            end
        end
        
        function ADC(ax, se)
            
            k = ax.UserData.trialNum;
            if k > se.numEpochs || k < 1
                return;
            end
            if ~ismember('adc', se.tableNames)
                return;
            end
            
            % Read signals
            tb = se.SliceTimeSeries('adc', ax.UserData.timeLimits, k, 'Fill', 'bleed');
            t = tb.time{1};
            fs = 1/diff(t(1:2));
            
            lpV = tb.forceV{1};
            lpH = tb.forceH{1};
            tuV = tb.tubeV{1};
            
            tuV = SL.Perch.FiltMovement(tuV, fs);
            tuV = tuV - median(tuV);
            
            lpV = lpV * 50 + 0.5;
            lpH = lpH * 50;
            tuV = tuV / 2 - 0.5;
            
            % Update plot
            cla(ax);
            plot(ax, t, tuV, 'k'); hold(ax, 'on');
            plot(ax, t, lpV, 'k');
            plot(ax, t, lpH, 'k');
            
            % Opto
            if ismember('opto1', tb.Properties.VariableNames)
                opto1 = tb.opto1{1} / SL.Param.vOptoAdcPerMod / 5;
                opto1(end) = 0;
                patch(ax, t, opto1, [0 .5 .75], 'FaceAlpha', .5, 'LineStyle', 'none');
                
                opto2 = tb.opto2{1} / SL.Param.vOptoAdcPerMod / 5;
                opto2(end) = 0;
                patch(ax, t, opto2-1, [0 .5 .75], 'FaceAlpha', .5, 'LineStyle', 'none');
            end
            
            ax.XLabel.String = 'Time (s)';
            ax.TickLength = [0 0];
            ax.Box = 'off';
            grid(ax, 'on');
            ax.YLim = [-1.2 1.2];
            title(ax, ...
                ['Perch signals (touch v., touch h., 20mN/unit; body v., AU) '...
                '{\color[rgb]{0,.5,.75}Opto modulation (right, left; frac. max)}']);
        end
        
        function BehavTrial(ax, se)
            
            k = ax.UserData.trialNum;
            if k > se.numEpochs || k < 1
                return;
            end
            
            % Read data
            [bt, bv] = se.GetTable('behavTime', 'behavValue');
            
            cla(ax);
            if ismember('hsv', se.tableNames)
                hsv = se.GetTable('hsv');
                SL.BehavFig.SingleTrial(ax, k, bt, bv, hsv);
            else
                SL.BehavFig.SingleTrial(ax, k, bt, bv);
            end
        end
        
        function BehavTrial2(ax, se)
            
            % Get parameters
            k = ax.UserData.trialNum;
            if k > se.numEpochs || k < 1
                return;
            end
            
            % Read data
            [bt, hsv] = se.GetTable('behavTime', 'hsv');
            adc = se.SliceTimeSeries('adc', ax.UserData.timeLimits, k, 'Fill', 'bleed');
            tADC = adc.time{1};
            
            cla(ax);
            hold(ax, 'on');
            
            % Events
            cueWin = [bt.cue(k), bt.cueOff(k)] + 0.005;
            MPlot.Blocks(cueWin, 55+[0 10], [.75 .5 0], 'FaceAlpha', 0.8, 'Parent', ax);
            
            waterWin = [bt.water(k), bt.waterOff(k)];
            MPlot.Blocks(waterWin, 55+[0 10], 'b', 'FaceAlpha', 0.8, 'Parent', ax);
            
            touchWin = [bt.lickOn{k}, bt.lickOff{k}];
            MPlot.Blocks(touchWin, [-45 45], [0 0 0], 'FaceAlpha', 0.2, 'Parent', ax);
            
            % Tracking
            if exist('hsv', 'var')
                hsvTime = hsv.time{k};
                ang = hsv.tongue_bottom_angle{k};
                len = hsv.tongue_bottom_length{k};
%                 SL.BehavFig.DiagAngDenoise(ax, hsvTime, ang, len);
                ang(len < SL.Param.minLen4Ang) = NaN;
                plot(ax, hsvTime, ang, 'k', 'MarkerSize', 2);
            end
            
            if ismember('opto1', adc.Properties.VariableNames)
                % Opto
                opto1 = adc.opto1{1} / SL.Param.vOptoAdcPerMod / 5;
                opto1(end) = 0;
                opto1 = opto1 * (105-75) + 75;
                patch(ax, tADC, opto1, [0 .5 .75], 'FaceAlpha', .5, 'LineStyle', 'none');
                
                ax.YLim = [-60 120];
                ax.YTick = [-45:45:45, 75, 105];
                ax.YTickLabel = [-45:45:45, 0, 8];
                ax.YLabel.String = '        \theta             opto';
                title(ax, [ ...
                    '{\color[rgb]{.75,.5,0}cue}, ' ...
                    '{\color{blue}water}, ' ...
                    '{\color[rgb]{.5,.5,.5}touch}, ' ...
                    '{\color{black}tongue angle \theta (°)}, '...
                    '{\color[rgb]{0,.5,.75}opto inhibition (mW)}']);
            else
%                 ax.YLim = [-60 75];
%                 ax.YTick = -45:45:45;
%                 ax.YTickLabel = -45:45:45;
%                 ax.YLabel.String = '\theta';
%                 title(ax, [ ...
%                     '{\color[rgb]{.75,.5,0}cue}, ' ...
%                     '{\color{blue}water}, ' ...
%                     '{\color{black}tongue angle \theta (°)}']);
                
                % Force
                lpV = adc.forceV{1};
                lpH = adc.forceH{1};
                lpV = lpV*1e3/5*10 - 80;
                lpH = lpH*1e3/5*10 - 95;
                plot(ax, tADC, lpV, 'k');
                plot(ax, tADC, lpH, 'k');
                
                ax.YLim = [-115 75];
                ax.YTick = [-100, -70, -45:45:45];
                ax.YTickLabel = [0, 15, -45:45:45];
                ax.YLabel.String = '{\itF_{lat} F_{vert}}        \theta               ';
                title(ax, [ ...
                    '{\color[rgb]{.75,.5,0}cue}, ' ...
                    '{\color{blue}water}, ' ...
                    '{\color[rgb]{.5,.5,.5}touch}, ' ...
                    '{\color{black}tongue angle \theta (°)}, '...
                    '{\color{black}vertical and lateral forces (mN)}']);
            end
            
            ax.XLabel.String = 'Time (s)';
            ax.TickDir = 'out';
            ax.FontSize = 9.5;
            ax.TitleFontSizeMultiplier = 1;
            grid(ax, 'on');
            box(ax, 'off');
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
        
        function CSD(ax, se)
            
            k = ax.UserData.trialNum;
            if k > se.numEpochs || k < 1
                return;
            end
            
            % Process spike times
            tb = se.SliceTimeSeries('LFP', ax.UserData.timeLimits, k, 'fill', 'bleed');
            t = tb.time{1};
            v = double(tb.series1{1});
            v = v(:,Probe.chanMapH3);
            v = Img23.Filt2Median(v, [5 5]);
            
            ddv = DGradient(v, 2, 1, '2ndOrder');
            nChan = size(v,2);
            
            % Update plot
            cla(ax);
            hold(ax, 'on');
            imagesc(ax, ddv', 'XData', t);
            colormap(ax, 'default');
            colorbar(ax, 'southoutside');
            ax.YDir = 'normal';
            ax.TickDir = 'out';
            
            ax.XLabel.String = 'Time (s)';
            ax.YLabel.String = 'Channel';
            ax.YLim = [0.5 nChan+.5];
            title(ax, 'Current source density (AU)');
        end
        
        function UnitPlots(ax0, eventdata, se)
            
            targetIdx = round(eventdata.IntersectionPoint(2));
            
            % Template
            uTpAvg = se.userData.spikeInfo.unit_mean_template(:,:,targetIdx);
            [nTime, nChan] = size(uTpAvg);
            
            figure(15876); clf
            ax = gca;
            MPlot.PlotTraceLadder((1:nTime)', uTpAvg*0.195, (1:nChan)', 'Color', 'k');
            
            ax.XLabel.String = 'Sample';
            ax.YLabel.String = 'Channel';
            axis tight;
            ax.YTick = 1 : nChan;
            ax.YTickLabel = arrayfun(@num2str, 1:nChan*20, 'Uni', false);
            ax.TickLength = [0 0];
            axis(ax, [0 nTime 0 nChan+1]);
            title(ax, ['Mean template of unit ', num2str(targetIdx)]);
            
            
            % Session raster
            tb = se.SliceEventTimes('spikeTime', ax0.UserData.timeLimits, [], targetIdx, 'Fill', 'bleed');
            [spkTimes, spkY, yTick] = SL.BehavFig.ConvertEventTimesForRasters(tb{:,1});
            
            figure(15877); clf
            ax = gca;
            MPlot.PlotPointAsLine(spkTimes, spkY, .6, 'Color', [0 0 0]);
            
            ax.XLabel.String = 'Time (s)';
            ax.YLabel.String = 'Trial';
            ax.TickLength = [0 0];
            ax.YDir = 'reverse';
            ax.YTick = yTick(1:2:end);
            ax.YTickLabel = arrayfun(@num2str, ax.YTick, 'Uni', false);
            grid(ax, 'on');
            axis(ax, [ax0.XLim spkY(1)-1 spkY(end)+1]);
            title(ax, ['Unit ', num2str(targetIdx)]);
        end
        
        function PlotSession(ax, se)
            
            if isfield(ax.UserData, 'timeLimits')
                bt = se.SliceEventTimes('behavTime', ax.UserData.timeLimits, 'Fill', 'bleed');
            else
                bt = se.GetTable('behavTime');
            end
            
            cla(ax);
            SL.BehavFig.TrialRaster(ax, bt);
        end
        
    end
end




