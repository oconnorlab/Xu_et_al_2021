classdef MUtil
    %MUtil Summary of this class goes here
    %   Detailed explanation goes here
    
    methods(Static)
        function s = CombineStructs(varargin)
            % Combine multiple structures into one. Field names must be unique across structures. 
            %
            %   s = MUtil.CombineStructs(varargin)
            % 
            
            tbs = cellfun(@(x) struct2table(x, 'AsArray', true), varargin, 'Uni', false);
            s = table2struct(cat(2, tbs{:}));
        end
        
        function dirTable = Dir2Table(varargin)
            % List folder contents. It is exactly the same function as dir(...) but output a table. 
            %
            %   dirTable = MUtil.DirTable( fileDir, fileName )
            %
            
            dirStruct = dir(varargin{:});
            dirTable = struct2table(dirStruct);
            
            for i = 1 : width(dirTable)
                if ischar(dirTable.(i))
                    dirTable.(i) = {dirTable.(i)};
                end
            end
        end
        
        function hit = MatchAnyRegExp(str, expressions)
            % Match any of the regular expressions
            % 
            %   hit = MUtil.MatchAnyRegExp(str, expressions)
            %
            
            expressions = cellstr(expressions);
            expressions = expressions(:);
            hit = cellfun(@(x) any(regexp(str, x, 'once')), expressions);
            hit = any(hit);
        end
        
        function xlsTb = ReadXls(xlsPath, sheetId, varargin)
            % General-purposed function to read a spreadsheet from Excel file
            % 
            %   xlsTb = Tongue.Util.ReadXls(xlsPath, sheetId)
            % 
            % Inputs
            %   xlsPath         The path of an Excel file. If left empty, a file selection window 
            %                   will show up.
            %   sheetId         The index or name of a sheet for multi-sheet file. The default is
            %                   the first sheet. 
            % Output
            %   xlsTb           The output table. 
            % 
            
            if nargin < 2
                sheetId = 1;
            end
            
            % Browse for an Excel file
            if ~exist(xlsPath, 'file')
                xlsPath = MBrowse.File('', 'Choose an Excel spreadsheet', {'*.xlsx', '*.xls'});
            end
            
            % Find spreadsheet index by name
            if ischar(sheetId)
                [~, sheetNames] = xlsfinfo(xlsPath);
                sheetId = find(strcmpi(sheetId, sheetNames), 1);
                if isempty(sheetId)
                    error('The specified spreadsheet does not exist');
                end
            end
            
            % Load spreadsheet
            xlsTb = readtable(xlsPath, 'Sheet', sheetId, varargin{:});
        end
        
    end
end

