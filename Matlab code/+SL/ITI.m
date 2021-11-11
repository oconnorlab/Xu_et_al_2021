classdef ITI
    methods(Static)
        function FormatExampleAxes(tWin, tCue)
            % Format the axes according to the variable being plotted
            ax = MPlot.Axes(gca);
            ax.XLim = tWin;
            ax.XAxis.Visible = 'off';
            ax.YAxis.Visible = 'off';
            plot([tCue tCue]', repmat(ax.YLim', [1 length(tCue)]), 'Color', [.75 .5 0])
        end
        
        function FormatRegAxes(ax, varName)
            % Format the axes according to the variable being plotted
            MPlot.Axes(ax);
            switch varName
                case '\tau'
                    ax.YLim = [-1 0];
                case 'I'
                    ax.YLim = [1 2]+[-1 1]*.1;
                    ax.YTick = [1 2];
                    ax.YTickLabel = {'RL', 'LR'};
                case '\theta'
                    ax.YLim = [-1 1]*20;
                    ax.YTick = [-1 0 1]*20;
                    ax.YLabel.String = 'degree';
                case 'L'
                    ax.YLim = [0 2.5];
                    ax.YLabel.String = 'mm';
                case 'L'''
                    ax.YLim = [-1 1] * 70;
                    ax.YLabel.String = 'mm/s';
            end
            if startsWith(varName, 'PC')
                ax.YTick = [];
            end
        end
        
    end
end

