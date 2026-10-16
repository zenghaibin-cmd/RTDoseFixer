function RTDoseFixerGUI()
% RTDoseFixerGUI - A MATLAB tool for importing CyberKnife RT Dose into Varian Eclipse or Elekta Monaco
% 
% Eclipse mode:
%   - Writes ReferencedRTPlanSequence pointing to Eclipse plan UID
%   - One-step process
%
% Monaco mode:
%   - Reads Plan UID from Monaco-exported Plan file
%   - Reads RTSS UID from Monaco-exported RTSS file
%   - Only modifies the two reference UIDs in RTDOSE
%
% Developer : Haibin Zeng
% Version   : 2026.10

    %% ===== Configuration file =====
    config_file = fullfile(tempdir, 'RTDoseFixer_config.mat');

    %% ===== Load previous configuration =====
    last_dir = ''; last_out = ''; last_tps = 'Eclipse';
    last_monaco_plan = ''; last_monaco_rtss = '';
    if exist(config_file, 'file')
        try
            cfg = load(config_file);
            if isfield(cfg, 'last_dir'), last_dir = cfg.last_dir; end
            if isfield(cfg, 'last_out'), last_out = cfg.last_out; end
            if isfield(cfg, 'last_tps'), last_tps = cfg.last_tps; end
            if isfield(cfg, 'last_monaco_plan'), last_monaco_plan = cfg.last_monaco_plan; end
            if isfield(cfg, 'last_monaco_rtss'), last_monaco_rtss = cfg.last_monaco_rtss; end
        catch
        end
    end

    original_scan_lines = {};

    %% ===== Color definitions =====
    bg_color     = [0.96, 0.97, 0.99];
    label_color  = [0.15, 0.20, 0.30];
    opt_color    = [0.55, 0.55, 0.55];
    btn_color    = [0.20, 0.45, 0.75];
    btn_text     = [1, 1, 1];
    sec_btn_bg   = [0.88, 0.91, 0.95];
    sec_btn_fg   = [0.15, 0.25, 0.40];
    panel_bg     = [0.92, 0.94, 0.97];
    step_done    = [0.20, 0.65, 0.35];
    step_active  = [0.20, 0.45, 0.75];
    step_inactive= [0.80, 0.83, 0.87];

    font_name = 'Times New Roman';
    font_size = 11;

    %% ===== Create main window =====
    fig = figure('Name', 'RT Dose Fixer', ...
                 'NumberTitle', 'off', ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none', ...
                 'Resize', 'off', ...
                 'Color', bg_color, ...
                 'Position', [250, 120, 1180, 720], ...
                 'CloseRequestFcn', @onClose, ...
                 'KeyPressFcn', @onKeyPress);

    %% ===== Title =====
    uicontrol('Style', 'text', ...
              'String', 'RT Dose Fixer', ...
              'HorizontalAlignment', 'center', ...
              'FontName', font_name, 'FontSize', 20, 'FontWeight', 'bold', ...
              'ForegroundColor', [0.15, 0.30, 0.55], ...
              'BackgroundColor', bg_color, ...
              'Position', [0, 675, 1180, 32]);

    uicontrol('Style', 'pushbutton', 'String', '?', ...
              'FontName', font_name, 'FontSize', 14, 'FontWeight', 'bold', ...
              'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
              'Position', [1100, 678, 40, 28], ...
              'Callback', @showHelp, ...
              'TooltipString', 'Help');

    %% ===== Step indicator =====
    step_texts = {'1. Select Folder', '2. Review Tags', '3. Fix', '4. Verify'};
    step_x = [40, 300, 560, 820];
    step_axes = gobjects(1,4);
    step_circles = gobjects(1,4);
    for i = 1:4
        step_axes(i) = axes('Parent', fig, 'Units', 'pixels', ...
                            'Position', [step_x(i), 640, 30, 30], ...
                            'XLim', [0,1], 'YLim', [0,1], ...
                            'XTick', [], 'YTick', [], 'Box', 'off', ...
                            'Color', bg_color);
        step_circles(i) = rectangle('Parent', step_axes(i), ...
                                    'Position', [0.1, 0.1, 0.8, 0.8], ...
                                    'Curvature', [1,1], ...
                                    'FaceColor', step_inactive, ...
                                    'EdgeColor', 'none');
        uicontrol('Style', 'text', ...
                  'String', step_texts{i}, ...
                  'HorizontalAlignment', 'left', ...
                  'FontName', font_name, 'FontSize', 10, ...
                  'ForegroundColor', label_color, ...
                  'BackgroundColor', bg_color, ...
                  'Position', [step_x(i)+35, 645, 200, 22]);
    end

    function setStep(n)
        for k = 1:4
            if k < n
                set(step_circles(k), 'FaceColor', step_done);
            elseif k == n
                set(step_circles(k), 'FaceColor', step_active);
            else
                set(step_circles(k), 'FaceColor', step_inactive);
            end
        end
        drawnow;
    end

    %% ============================================================
    %% LEFT COLUMN - Common controls
    %% ============================================================

    %% Target TPS
    uicontrol('Style', 'text', 'String', 'Target TPS:', ...
              'HorizontalAlignment', 'left', ...
              'FontName', font_name, 'FontSize', font_size, 'FontWeight', 'bold', ...
              'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
              'Position', [40, 600, 140, 24]);

    tps_group = uibuttongroup('Parent', fig, 'Units', 'pixels', ...
                              'Position', [185, 595, 500, 32], ...
                              'BorderType', 'none', ...
                              'BackgroundColor', bg_color, ...
                              'SelectionChangedFcn', @onTpsChange);
    rb_eclipse = uicontrol(tps_group, 'Style', 'radiobutton', ...
                           'String', 'Eclipse (Varian)', ...
                           'FontName', font_name, 'FontSize', font_size, ...
                           'ForegroundColor', label_color, ...
                           'BackgroundColor', bg_color, ...
                           'Position', [0, 5, 220, 24], ...
                           'Value', strcmp(last_tps, 'Eclipse'));
    rb_monaco = uicontrol(tps_group, 'Style', 'radiobutton', ...
                          'String', 'Monaco (Elekta)', ...
                          'FontName', font_name, 'FontSize', font_size, ...
                          'ForegroundColor', label_color, ...
                          'BackgroundColor', bg_color, ...
                          'Position', [240, 5, 220, 24], ...
                          'Value', strcmp(last_tps, 'Monaco'));

    %% Working Folder
    uicontrol('Style', 'text', 'String', 'Working Folder:', ...
              'HorizontalAlignment', 'left', ...
              'FontName', font_name, 'FontSize', font_size, 'FontWeight', 'bold', ...
              'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
              'Position', [40, 560, 140, 24]);

    edit_dir = uicontrol('Style', 'edit', ...
                         'HorizontalAlignment', 'left', ...
                         'FontName', font_name, 'FontSize', font_size, ...
                         'Position', [185, 557, 410, 30], ...
                         'String', last_dir);

    btn_dir = uicontrol('Style', 'pushbutton', 'String', 'Browse...', ...
                        'FontName', font_name, 'FontSize', font_size, ...
                        'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
                        'Position', [605, 557, 80, 30], ...
                        'Callback', @selectDir, ...
                        'TooltipString', 'Ctrl+O');

    %% ============================================================
    %% LEFT COLUMN - Eclipse-specific controls
    %% ============================================================

    ec.lbl_uid   = uicontrol('Style', 'text', 'String', 'Plan UID:', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [40, 517, 140, 24]);
    ec.lbl_uidopt= uicontrol('Style', 'text', 'String', '(Optional)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', 9, ...
                             'ForegroundColor', opt_color, 'BackgroundColor', bg_color, ...
                             'Position', [120, 517, 80, 24]);
    ec.edit_uid  = uicontrol('Style', 'edit', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'Position', [185, 514, 500, 30], ...
                             'String', '');
    ec.hint_uid  = uicontrol('Style', 'text', ...
                             'String', '(If filled, this UID takes priority over RTPLAN file)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', 9, ...
                             'ForegroundColor', [0.45, 0.50, 0.55], ...
                             'BackgroundColor', bg_color, ...
                             'Position', [185, 489, 500, 20]);

    ec.chk_dose  = uicontrol('Style', 'checkbox', ...
                             'String', 'Select RT Dose file directly  (Optional)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [40, 455, 350, 24], ...
                             'Value', 0, 'Callback', @toggleDoseDirect);
    ec.lbl_dose  = uicontrol('Style', 'text', 'String', 'RT Dose File:', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [60, 420, 125, 24]);
    ec.edit_dose = uicontrol('Style', 'edit', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'Position', [185, 417, 410, 30], ...
                             'String', '', 'Enable', 'off');
    ec.btn_dose  = uicontrol('Style', 'pushbutton', 'String', 'Browse...', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
                             'Position', [605, 417, 80, 30], ...
                             'Enable', 'off', 'Callback', @selectDoseDirect);

    ec.chk_plan  = uicontrol('Style', 'checkbox', ...
                             'String', 'Select RTPLAN file directly  (Optional)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [40, 382, 350, 24], ...
                             'Value', 0, 'Callback', @togglePlanDirect);
    ec.lbl_plan  = uicontrol('Style', 'text', 'String', 'RTPLAN File:', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [60, 347, 125, 24]);
    ec.edit_plan = uicontrol('Style', 'edit', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'Position', [185, 344, 410, 30], ...
                             'String', '', 'Enable', 'off');
    ec.btn_plan  = uicontrol('Style', 'pushbutton', 'String', 'Browse...', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
                             'Position', [605, 344, 80, 30], ...
                             'Enable', 'off', 'Callback', @selectPlanDirect);

    ec.chk_custom= uicontrol('Style', 'checkbox', ...
                             'String', 'Custom output path  (Optional)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [40, 305, 300, 26], ...
                             'Value', 0, 'Callback', @toggleCustomPath);
    ec.lbl_out   = uicontrol('Style', 'text', 'String', 'Output File:', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [60, 270, 125, 24]);
    ec.edit_out  = uicontrol('Style', 'edit', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'Position', [185, 267, 410, 30], ...
                             'String', '', 'Enable', 'off');
    ec.btn_out   = uicontrol('Style', 'pushbutton', 'String', 'Save As...', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
                             'Position', [605, 267, 80, 30], ...
                             'Enable', 'off', 'Callback', @selectOutputFile);
    ec.hint_out  = uicontrol('Style', 'text', ...
                             'String', '(If unchecked: overwrite the original RT Dose file)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', 9, ...
                             'ForegroundColor', [0.45, 0.50, 0.55], ...
                             'BackgroundColor', bg_color, ...
                             'Position', [40, 242, 540, 20]);

    %% ============================================================
    %% LEFT COLUMN - Monaco-specific controls
    %% ============================================================

    mc.lbl_plan  = uicontrol('Style', 'text', 'String', 'Monaco Plan File:', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [40, 517, 140, 24]);
    mc.edit_plan = uicontrol('Style', 'edit', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'Position', [185, 514, 410, 30], ...
                             'String', last_monaco_plan);
    mc.btn_plan  = uicontrol('Style', 'pushbutton', 'String', 'Browse...', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
                             'Position', [605, 514, 80, 30], ...
                             'Callback', @selectMonacoPlan);
    mc.hint_plan = uicontrol('Style', 'text', ...
                             'String', '(Monaco-exported RT Plan file, UID will be read automatically)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', 9, ...
                             'ForegroundColor', [0.45, 0.50, 0.55], ...
                             'BackgroundColor', bg_color, ...
                             'Position', [185, 489, 500, 20]);

    mc.lbl_rtss  = uicontrol('Style', 'text', 'String', 'Monaco RTSS File:', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [40, 455, 140, 24]);
    mc.edit_rtss = uicontrol('Style', 'edit', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'Position', [185, 452, 410, 30], ...
                             'String', last_monaco_rtss);
    mc.btn_rtss  = uicontrol('Style', 'pushbutton', 'String', 'Browse...', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
                             'Position', [605, 452, 80, 30], ...
                             'Callback', @selectMonacoRTSS);
    mc.hint_rtss = uicontrol('Style', 'text', ...
                             'String', '(Monaco-exported RT Structure Set file, UID will be read automatically)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', 9, ...
                             'ForegroundColor', [0.45, 0.50, 0.55], ...
                             'BackgroundColor', bg_color, ...
                             'Position', [185, 427, 500, 20]);

    mc.chk_dose  = uicontrol('Style', 'checkbox', ...
                             'String', 'Select RT Dose file directly  (Optional)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [40, 390, 350, 24], ...
                             'Value', 0, 'Callback', @toggleDoseDirect);
    mc.lbl_dose  = uicontrol('Style', 'text', 'String', 'RT Dose File:', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [60, 355, 125, 24]);
    mc.edit_dose = uicontrol('Style', 'edit', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'Position', [185, 352, 410, 30], ...
                             'String', '', 'Enable', 'off');
    mc.btn_dose  = uicontrol('Style', 'pushbutton', 'String', 'Browse...', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
                             'Position', [605, 352, 80, 30], ...
                             'Enable', 'off', 'Callback', @selectDoseDirect);

    mc.chk_custom= uicontrol('Style', 'checkbox', ...
                             'String', 'Custom output path  (Optional)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [40, 313, 300, 26], ...
                             'Value', 0, 'Callback', @toggleCustomPath);
    mc.lbl_out   = uicontrol('Style', 'text', 'String', 'Output File:', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
                             'Position', [60, 278, 125, 24]);
    mc.edit_out  = uicontrol('Style', 'edit', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'Position', [185, 275, 410, 30], ...
                             'String', '', 'Enable', 'off');
    mc.btn_out   = uicontrol('Style', 'pushbutton', 'String', 'Save As...', ...
                             'FontName', font_name, 'FontSize', font_size, ...
                             'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
                             'Position', [605, 275, 80, 30], ...
                             'Enable', 'off', 'Callback', @selectOutputFile);
    mc.hint_out  = uicontrol('Style', 'text', ...
                             'String', '(If unchecked: overwrite the original RT Dose file)', ...
                             'HorizontalAlignment', 'left', ...
                             'FontName', font_name, 'FontSize', 9, ...
                             'ForegroundColor', [0.45, 0.50, 0.55], ...
                             'BackgroundColor', bg_color, ...
                             'Position', [40, 250, 540, 20]);

    %% ============================================================
    %% Common: Fix button, progress bar, status
    %% ============================================================

    btn_fix = uicontrol('Style', 'pushbutton', 'String', 'Fix RT Dose (Enter)', ...
                        'FontName', font_name, 'FontSize', 13, 'FontWeight', 'bold', ...
                        'ForegroundColor', btn_text, 'BackgroundColor', btn_color, ...
                        'Position', [250, 180, 220, 48], ...
                        'Callback', @runFix);

    progress_ax = axes('Parent', fig, 'Units', 'pixels', ...
                       'Position', [40, 140, 645, 22], ...
                       'XLim', [0, 100], 'YLim', [0, 1], ...
                       'Box', 'on', 'XTick', [], 'YTick', [], ...
                       'Color', [0.92, 0.94, 0.97], ...
                       'XColor', [0.75, 0.78, 0.82], ...
                       'YColor', [0.75, 0.78, 0.82], ...
                       'Visible', 'off');

    progress_rect = rectangle('Parent', progress_ax, ...
                              'Position', [0, 0, 0, 1], ...
                              'FaceColor', btn_color, ...
                              'EdgeColor', 'none', ...
                              'Visible', 'off');

    progress_text = uicontrol('Style', 'text', 'String', '0%', ...
                              'HorizontalAlignment', 'center', ...
                              'FontName', font_name, 'FontSize', 9, ...
                              'ForegroundColor', [0.15, 0.20, 0.30], ...
                              'BackgroundColor', [0.92, 0.94, 0.97], ...
                              'Position', [40, 140, 645, 22], ...
                              'Visible', 'off');

    txt_status = uicontrol('Style', 'text', 'String', 'Ready', ...
                           'HorizontalAlignment', 'left', ...
                           'FontName', font_name, 'FontSize', font_size, ...
                           'ForegroundColor', [0.30, 0.45, 0.60], ...
                           'BackgroundColor', bg_color, ...
                           'Position', [40, 85, 640, 45]);

    %% ============================================================
    %% RIGHT COLUMN - Tag Inspection
    %% ============================================================

    uicontrol('Style', 'text', 'String', 'Tag Inspection:', ...
              'HorizontalAlignment', 'left', ...
              'FontName', font_name, 'FontSize', font_size, 'FontWeight', 'bold', ...
              'ForegroundColor', label_color, 'BackgroundColor', bg_color, ...
              'Position', [720, 600, 250, 24]);

    uicontrol('Style', 'pushbutton', 'String', 'Copy', ...
              'FontName', font_name, 'FontSize', 10, ...
              'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
              'Position', [860, 598, 80, 26], ...
              'Callback', @copyLog, ...
              'TooltipString', 'Copy to clipboard');

    uicontrol('Style', 'pushbutton', 'String', 'Export Log', ...
              'FontName', font_name, 'FontSize', 10, ...
              'BackgroundColor', sec_btn_bg, 'ForegroundColor', sec_btn_fg, ...
              'Position', [950, 598, 100, 26], ...
              'Callback', @exportLog, ...
              'TooltipString', 'Ctrl+E');

    txt_inspect = uicontrol('Style', 'listbox', ...
                            'String', {'No folder selected'}, ...
                            'HorizontalAlignment', 'left', ...
                            'FontName', font_name, 'FontSize', 9, ...
                            'ForegroundColor', [0.20, 0.35, 0.55], ...
                            'BackgroundColor', panel_bg, ...
                            'Position', [720, 130, 420, 460], ...
                            'Max', 2, 'Min', 0, ...
                            'Value', []);

    %% ============================================================
    %% BOTTOM
    %% ============================================================

    uicontrol('Style', 'text', ...
              'String', 'Disclaimer: This tool is provided for research and clinical support purposes only. Users are responsible for verifying all DICOM data before clinical use.', ...
              'HorizontalAlignment', 'left', ...
              'FontName', font_name, 'FontSize', 9, ...
              'ForegroundColor', [0.55, 0.55, 0.55], ...
              'BackgroundColor', bg_color, ...
              'Position', [40, 48, 1040, 20]);

    uicontrol('Style', 'text', ...
              'String', 'Developer: Haibin Zeng    |    Version: 2026.10', ...
              'HorizontalAlignment', 'left', ...
              'FontName', font_name, 'FontSize', 9, ...
              'ForegroundColor', [0.55, 0.55, 0.55], ...
              'BackgroundColor', bg_color, ...
              'Position', [40, 26, 1100, 20]);

    %% ===== Initial visibility =====
    applyTpsVisibility();

    %% ===== Startup scan =====
    if ~isempty(last_dir) && exist(last_dir, 'dir')
        inspectFolder(last_dir);
        setStep(2);
    else
        setStep(1);
    end

    %% ============================================================
    %% Visibility / mode switching
    %% ============================================================

    function result = isMonaco()
        result = contains(get(get(tps_group, 'SelectedObject'), 'String'), 'Monaco');
    end

    function applyTpsVisibility()
        ec_handles = [ec.lbl_uid, ec.lbl_uidopt, ec.edit_uid, ec.hint_uid, ...
                      ec.chk_dose, ec.lbl_dose, ec.edit_dose, ec.btn_dose, ...
                      ec.chk_plan, ec.lbl_plan, ec.edit_plan, ec.btn_plan, ...
                      ec.chk_custom, ec.lbl_out, ec.edit_out, ec.btn_out, ec.hint_out];
        mc_handles = [mc.lbl_plan, mc.edit_plan, mc.btn_plan, mc.hint_plan, ...
                      mc.lbl_rtss, mc.edit_rtss, mc.btn_rtss, mc.hint_rtss, ...
                      mc.chk_dose, mc.lbl_dose, mc.edit_dose, mc.btn_dose, ...
                      mc.chk_custom, mc.lbl_out, mc.edit_out, mc.btn_out, mc.hint_out];

        if isMonaco()
            set(ec_handles, 'Visible', 'off');
            set(mc_handles, 'Visible', 'on');
        else
            set(ec_handles, 'Visible', 'on');
            set(mc_handles, 'Visible', 'off');
        end
        drawnow;
    end

    function onTpsChange(~, ~)
        applyTpsVisibility();
    end

    %% ============================================================
    %% Common callbacks
    %% ============================================================

    function selectDir(~, ~)
        d = uigetdir(get(edit_dir, 'String'), 'Select working folder');
        if isequal(d, 0), return; end
        set(edit_dir, 'String', d);
        drawnow;
        inspectFolder(d);
        setStep(2);
    end

    function toggleDoseDirect(src, ~)
        if isMonaco()
            dose_edit = mc.edit_dose; dose_btn = mc.btn_dose;
        else
            dose_edit = ec.edit_dose; dose_btn = ec.btn_dose;
        end
        if get(src, 'Value') == 1
            set(dose_edit, 'Enable', 'on');
            set(dose_btn, 'Enable', 'on');
        else
            set(dose_edit, 'Enable', 'off');
            set(dose_btn, 'Enable', 'off');
            set(dose_edit, 'String', '');
        end
    end

    function togglePlanDirect(src, ~)
        if get(src, 'Value') == 1
            set(ec.edit_plan, 'Enable', 'on');
            set(ec.btn_plan, 'Enable', 'on');
        else
            set(ec.edit_plan, 'Enable', 'off');
            set(ec.btn_plan, 'Enable', 'off');
            set(ec.edit_plan, 'String', '');
        end
    end

    function toggleCustomPath(src, ~)
        if isMonaco()
            out_edit = mc.edit_out; out_btn = mc.btn_out;
        else
            out_edit = ec.edit_out; out_btn = ec.btn_out;
        end
        if get(src, 'Value') == 1
            set(out_edit, 'Enable', 'on');
            set(out_btn, 'Enable', 'on');
        else
            set(out_edit, 'Enable', 'off');
            set(out_btn, 'Enable', 'off');
            set(out_edit, 'String', '');
        end
    end

    function selectDoseDirect(~, ~)
        [f, p] = uigetfile({'*.*', 'DICOM file (*.*)'}, 'Select RT Dose file');
        if isequal(f, 0), return; end
        if isMonaco()
            set(mc.edit_dose, 'String', fullfile(p, f));
        else
            set(ec.edit_dose, 'String', fullfile(p, f));
        end
    end

    function selectPlanDirect(~, ~)
        [f, p] = uigetfile({'*.*', 'DICOM file (*.*)'}, 'Select RTPLAN file');
        if isequal(f, 0), return; end
        set(ec.edit_plan, 'String', fullfile(p, f));
    end

    function selectMonacoPlan(~, ~)
        [f, p] = uigetfile({'*.*', 'DICOM file (*.*)'}, 'Select Monaco-exported Plan file');
        if isequal(f, 0), return; end
        set(mc.edit_plan, 'String', fullfile(p, f));
    end

    function selectMonacoRTSS(~, ~)
        [f, p] = uigetfile({'*.*', 'DICOM file (*.*)'}, 'Select Monaco-exported RTSS file');
        if isequal(f, 0), return; end
        set(mc.edit_rtss, 'String', fullfile(p, f));
    end

    function selectOutputFile(~, ~)
        [f, p] = uiputfile({'*.dcm', 'DICOM file (*.dcm)'}, 'Save modified RT Dose');
        if isequal(f, 0), return; end
        if isMonaco()
            set(mc.edit_out, 'String', fullfile(p, f));
        else
            set(ec.edit_out, 'String', fullfile(p, f));
        end
    end

    %% ============================================================
    %% Folder inspection
    %% ============================================================

    function inspectFolder(d)
        [plan_files, dose_files, rtss_files] = scanDicomFiles(d);
        ts = datestr(now, 'yyyy-mm-dd HH:MM:SS');

        lines = {};
        lines{end+1} = sprintf('[%s] Folder scan: RTPLAN %d, RT Dose %d, RTSS %d', ...
                               ts, length(plan_files), length(dose_files), length(rtss_files));
        lines{end+1} = '';

        if ~isempty(plan_files)
            plan_file = fullfile(d, plan_files(1).name);
            try
                plan_info = dicominfo(plan_file);
                lines{end+1} = sprintf('[%s] --- RTPLAN ---', ts);
                lines{end+1} = 'SOP Instance UID:';
                lines{end+1} = sprintf('  %s', plan_info.SOPInstanceUID);
                lines{end+1} = sprintf('Patient ID: %s', plan_info.PatientID);
            catch
                lines{end+1} = sprintf('[%s] RTPLAN read failed', ts);
            end
        else
            lines{end+1} = sprintf('[%s] RTPLAN not found', ts);
        end
        lines{end+1} = '';

        if ~isempty(dose_files)
            dose_file = fullfile(d, dose_files(1).name);
            try
                dose_info = dicominfo(dose_file);
                lines{end+1} = sprintf('[%s] --- RT Dose (original) ---', ts);
                lines{end+1} = 'SOP Instance UID:';
                lines{end+1} = sprintf('  %s', dose_info.SOPInstanceUID);
                if isfield(dose_info, 'ReferencedRTPlanSequence')
                    lines{end+1} = 'ReferencedRTPlanSequence: PRESENT';
                else
                    lines{end+1} = 'ReferencedRTPlanSequence: MISSING';
                end
                if isfield(dose_info, 'ReferencedStructureSetSequence')
                    lines{end+1} = 'ReferencedStructureSetSequence: PRESENT';
                else
                    lines{end+1} = 'ReferencedStructureSetSequence: NOT PRESENT';
                end
                lines{end+1} = sprintf('Patient ID: %s', dose_info.PatientID);
            catch
                lines{end+1} = sprintf('[%s] RT Dose read failed', ts);
            end
        else
            lines{end+1} = sprintf('[%s] RT Dose not found', ts);
        end

        original_scan_lines = lines;
        set(txt_inspect, 'String', lines, 'Value', []);
        set(txt_status, 'String', 'Folder pre-scan complete');
        drawnow;
    end

    %% ============================================================
    %% Progress bar
    %% ============================================================

    function updateProgress(pct, msg)
        pct = max(0, min(100, pct));
        set(progress_rect, 'Position', [0, 0, pct, 1]);
        set(progress_text, 'String', sprintf('%d%%', round(pct)));
        if nargin > 1 && ~isempty(msg)
            set(txt_status, 'String', msg);
        end
        drawnow;
    end

    function showProgress()
        set(progress_ax, 'Visible', 'on');
        set(progress_rect, 'Visible', 'on');
        set(progress_text, 'Visible', 'on');
        updateProgress(0, '');
        drawnow;
    end

    function hideProgress()
        set(progress_ax, 'Visible', 'off');
        set(progress_rect, 'Visible', 'off');
        set(progress_text, 'Visible', 'off');
        updateProgress(0, '');
        drawnow;
    end

    %% ============================================================
    %% Run fix
    %% ============================================================

    function runFix(~, ~)
        try
            setStep(3);
            showProgress();
            updateProgress(0, 'Validating inputs...');

            if isMonaco()
                runFixMonaco();
            else
                runFixEclipse();
            end
        catch ME
            set(txt_status, 'String', ['Error: ' ME.message]);
            errordlg(ME.message, 'Processing failed');
            hideProgress();
            setStep(2);
        end
    end

    %% ---------- Eclipse mode ----------
    function runFixEclipse()
        updateProgress(10, 'Locating RT Dose file...');
        use_dose_direct = get(ec.chk_dose, 'Value') == 1;
        if use_dose_direct
            rd_file = get(ec.edit_dose, 'String');
            if isempty(rd_file) || ~exist(rd_file, 'file')
                errordlg('Direct RT Dose file is checked, but no valid file selected.', 'Error');
                hideProgress(); setStep(2); return;
            end
        else
            work_dir = get(edit_dir, 'String');
            if isempty(work_dir) || ~exist(work_dir, 'dir')
                errordlg('Please select a valid working folder.', 'Error');
                hideProgress(); setStep(1); return;
            end
            [~, dose_files, ~] = scanDicomFiles(work_dir);
            if isempty(dose_files)
                errordlg('No RT Dose file found in the folder', 'Error');
                hideProgress(); setStep(2); return;
            end
            rd_file = fullfile(work_dir, dose_files(1).name);
        end

        updateProgress(25, 'Determining Plan UID...');
        plan_uid = ''; plan_patient_id = ''; plan_patient_name = [];
        use_plan_file = false;
        source_info = '';

        manual_uid = strtrim(get(ec.edit_uid, 'String'));
        if ~isempty(manual_uid)
            plan_uid = manual_uid;
            source_info = 'Manual UID';
        else
            use_plan_direct = get(ec.chk_plan, 'Value') == 1;
            if use_plan_direct
                plan_file = get(ec.edit_plan, 'String');
                if isempty(plan_file) || ~exist(plan_file, 'file')
                    errordlg('Direct RTPLAN file is checked, but no valid file selected.', 'Error');
                    hideProgress(); setStep(2); return;
                end
                try
                    plan_info = dicominfo(plan_file);
                    plan_uid = plan_info.SOPInstanceUID;
                    plan_patient_id = plan_info.PatientID;
                    if isfield(plan_info, 'PatientName')
                        plan_patient_name = plan_info.PatientName;
                    end
                    use_plan_file = true;
                    source_info = 'Direct RTPLAN file';
                catch
                    errordlg('Failed to read the selected RTPLAN file.', 'Error');
                    hideProgress(); setStep(2); return;
                end
            else
                work_dir = get(edit_dir, 'String');
                if ~isempty(work_dir) && exist(work_dir, 'dir')
                    [plan_files, ~, ~] = scanDicomFiles(work_dir);
                    if ~isempty(plan_files)
                        plan_file = fullfile(work_dir, plan_files(1).name);
                        try
                            plan_info = dicominfo(plan_file);
                            plan_uid = plan_info.SOPInstanceUID;
                            plan_patient_id = plan_info.PatientID;
                            if isfield(plan_info, 'PatientName')
                                plan_patient_name = plan_info.PatientName;
                            end
                            use_plan_file = true;
                            source_info = 'RTPLAN file (folder scan)';
                        catch
                        end
                    end
                end
            end
        end

        if isempty(plan_uid)
            errordlg('No Plan UID entered and no RTPLAN file available.', 'Error');
            hideProgress(); setStep(2); return;
        end

        updateProgress(45, 'Reading RT Dose file...');
        info = dicominfo(rd_file);
        pixel_data = dicomread(rd_file);

        updateProgress(60, 'Modifying DICOM tags...');
        plan_seq.Item_1.ReferencedSOPClassUID = '1.2.840.10008.5.1.4.1.1.481.5';
        plan_seq.Item_1.ReferencedSOPInstanceUID = plan_uid;
        info.ReferencedRTPlanSequence = plan_seq;

        if isfield(info, 'ReferencedStructureSetSequence')
            info = rmfield(info, 'ReferencedStructureSetSequence');
        end

        if use_plan_file
            info.PatientID = plan_patient_id;
            if ~isempty(plan_patient_name)
                info.PatientName = plan_patient_name;
            end
        end

        updateProgress(70, 'Preparing output...');
        if get(ec.chk_custom, 'Value') == 1
            output_file = get(ec.edit_out, 'String');
            if isempty(output_file)
                errordlg('Custom output path is checked, but no output file specified.', 'Error');
                hideProgress(); setStep(2); return;
            end
        else
            output_file = rd_file;
        end

        updateProgress(80, 'Writing modified file...');
        warning('off', 'dicomwrite:ignoredOptions');
        dicomwrite(pixel_data, output_file, info, 'CreateMode', 'copy');
        warning('on', 'dicomwrite:ignoredOptions');

        updateProgress(92, 'Verifying...');
        new_info = dicominfo(output_file);
        ts = datestr(now, 'yyyy-mm-dd HH:MM:SS');

        existing = original_scan_lines;
        if isempty(existing), existing = get(txt_inspect, 'String'); end
        if ischar(existing), existing = {existing}; end
        existing = existing(:);

        append_lines = {};
        append_lines{end+1} = '';
        append_lines{end+1} = sprintf('[%s] ========== POST-FIX (Eclipse) ==========', ts);
        append_lines{end+1} = 'RT Dose SOP Instance UID:';
        append_lines{end+1} = sprintf('  %s', new_info.SOPInstanceUID);
        append_lines{end+1} = 'Target Plan UID:';
        append_lines{end+1} = sprintf('  %s', plan_uid);
        if isfield(new_info, 'ReferencedRTPlanSequence')
            new_uid = new_info.ReferencedRTPlanSequence.Item_1.ReferencedSOPInstanceUID;
            append_lines{end+1} = 'ReferencedSOPInstanceUID:';
            append_lines{end+1} = sprintf('  %s', new_uid);
            if strcmp(new_uid, plan_uid)
                append_lines{end+1} = 'UID MATCH: SUCCESS';
            else
                append_lines{end+1} = 'UID MATCH: FAILED';
            end
        end
        append_lines = append_lines(:);

        set(txt_inspect, 'String', [existing; append_lines], 'Value', []);

        updateProgress(100, sprintf('Fix complete (Eclipse, %s)', source_info));
        setStep(4);
        pause(0.3);
        hideProgress();

        last_dir = get(edit_dir, 'String');
        last_out = get(ec.edit_out, 'String');
        last_tps = 'Eclipse';
        save(config_file, 'last_dir', 'last_out', 'last_tps');

        showSuccessDialog(source_info, output_file, plan_uid, 'Eclipse');
    end

    %% ---------- Monaco mode ----------
    function runFixMonaco()
        updateProgress(10, 'Reading Monaco Plan file...');
        monaco_plan_file = get(mc.edit_plan, 'String');
        if isempty(monaco_plan_file) || ~exist(monaco_plan_file, 'file')
            errordlg('Please select a valid Monaco Plan file.', 'Error');
            hideProgress(); setStep(2); return;
        end
        try
            plan_info = dicominfo(monaco_plan_file);
            monaco_plan_uid = plan_info.SOPInstanceUID;
        catch
            errordlg('Failed to read Monaco Plan file.', 'Error');
            hideProgress(); setStep(2); return;
        end
        fprintf('Monaco Plan UID: %s\n', monaco_plan_uid);

        updateProgress(25, 'Reading Monaco RTSS file...');
        monaco_rtss_file = get(mc.edit_rtss, 'String');
        if isempty(monaco_rtss_file) || ~exist(monaco_rtss_file, 'file')
            errordlg('Please select a valid Monaco RTSS file.', 'Error');
            hideProgress(); setStep(2); return;
        end
        try
            rtss_info = dicominfo(monaco_rtss_file);
            monaco_rtss_uid = rtss_info.SOPInstanceUID;
        catch
            errordlg('Failed to read Monaco RTSS file.', 'Error');
            hideProgress(); setStep(2); return;
        end
        fprintf('Monaco RTSS UID: %s\n', monaco_rtss_uid);

        updateProgress(40, 'Locating RT Dose file...');
        use_dose_direct = get(mc.chk_dose, 'Value') == 1;
        if use_dose_direct
            rd_file = get(mc.edit_dose, 'String');
            if isempty(rd_file) || ~exist(rd_file, 'file')
                errordlg('Direct RT Dose file is checked, but no valid file selected.', 'Error');
                hideProgress(); setStep(2); return;
            end
        else
            work_dir = get(edit_dir, 'String');
            if isempty(work_dir) || ~exist(work_dir, 'dir')
                errordlg('Please select a valid working folder.', 'Error');
                hideProgress(); setStep(1); return;
            end
            [~, dose_files, ~] = scanDicomFiles(work_dir);
            if isempty(dose_files)
                errordlg('No RT Dose file found in the folder', 'Error');
                hideProgress(); setStep(2); return;
            end
            rd_file = fullfile(work_dir, dose_files(1).name);
        end

        updateProgress(60, 'Modifying RT Dose reference UIDs...');
        info = dicominfo(rd_file);
        pixel_data = dicomread(rd_file);

        plan_seq.Item_1.ReferencedSOPClassUID = '1.2.840.10008.5.1.4.1.1.481.5';
        plan_seq.Item_1.ReferencedSOPInstanceUID = monaco_plan_uid;
        info.ReferencedRTPlanSequence = plan_seq;

        rtss_seq.Item_1.ReferencedSOPClassUID = '1.2.840.10008.5.1.4.1.1.481.3';
        rtss_seq.Item_1.ReferencedSOPInstanceUID = monaco_rtss_uid;
        info.ReferencedStructureSetSequence = rtss_seq;

        updateProgress(70, 'Preparing output...');
        if get(mc.chk_custom, 'Value') == 1
            output_file = get(mc.edit_out, 'String');
            if isempty(output_file)
                errordlg('Custom output path is checked, but no output file specified.', 'Error');
                hideProgress(); setStep(2); return;
            end
        else
            output_file = rd_file;
        end

        updateProgress(80, 'Writing modified file...');
        warning('off', 'dicomwrite:ignoredOptions');
        dicomwrite(pixel_data, output_file, info, 'CreateMode', 'copy');
        warning('on', 'dicomwrite:ignoredOptions');

        updateProgress(92, 'Verifying...');
        new_info = dicominfo(output_file);
        ts = datestr(now, 'yyyy-mm-dd HH:MM:SS');

        existing = original_scan_lines;
        if isempty(existing), existing = get(txt_inspect, 'String'); end
        if ischar(existing), existing = {existing}; end
        existing = existing(:);

        append_lines = {};
        append_lines{end+1} = '';
        append_lines{end+1} = sprintf('[%s] ========== POST-FIX (Monaco) ==========', ts);
        append_lines{end+1} = 'RT Dose SOP Instance UID:';
        append_lines{end+1} = sprintf('  %s', new_info.SOPInstanceUID);
        append_lines{end+1} = 'Monaco Plan UID:';
        append_lines{end+1} = sprintf('  %s', monaco_plan_uid);
        append_lines{end+1} = 'Monaco RTSS UID:';
        append_lines{end+1} = sprintf('  %s', monaco_rtss_uid);
        if isfield(new_info, 'ReferencedRTPlanSequence')
            new_uid = new_info.ReferencedRTPlanSequence.Item_1.ReferencedSOPInstanceUID;
            if strcmp(new_uid, monaco_plan_uid)
                append_lines{end+1} = 'PLAN UID MATCH: SUCCESS';
            else
                append_lines{end+1} = 'PLAN UID MATCH: FAILED';
            end
        end
        append_lines = append_lines(:);

        set(txt_inspect, 'String', [existing; append_lines], 'Value', []);

        updateProgress(100, 'Fix complete (Monaco)');
        setStep(4);
        pause(0.3);
        hideProgress();

        last_dir = get(edit_dir, 'String');
        last_out = get(mc.edit_out, 'String');
        last_tps = 'Monaco';
        last_monaco_plan = monaco_plan_file;
        last_monaco_rtss = monaco_rtss_file;
        save(config_file, 'last_dir', 'last_out', 'last_tps', ...
             'last_monaco_plan', 'last_monaco_rtss');

        showSuccessDialog('Monaco files', output_file, monaco_plan_uid, 'Monaco');
    end

    %% ============================================================
    %% Copy / Export / Help
    %% ============================================================

    function copyLog(~, ~)
        content = get(txt_inspect, 'String');
        if ischar(content), content = {content}; end
        txt = strjoin(content, newline);
        clipboard('copy', txt);
        set(txt_status, 'String', 'Tag info copied to clipboard');
    end

    function exportLog(~, ~)
        content = get(txt_inspect, 'String');
        if ischar(content), content = {content}; end
        if isempty(content) || (length(content) == 1 && strcmp(content{1}, 'No folder selected'))
            errordlg('No tag information to export. Please select a folder first.', 'Error');
            return;
        end

        default_name = sprintf('RTDoseFixer_log_%s.txt', datestr(now, 'yyyymmdd_HHMMSS'));
        [f, p] = uiputfile({'*.txt', 'Log file (*.txt)'}, 'Export Tag Inspection Log', default_name);
        if isequal(f, 0), return; end

        fid = fopen(fullfile(p, f), 'w');
        if fid == -1
            errordlg('Cannot create log file', 'Error');
            return;
        end
        fprintf(fid, '========================================\n');
        fprintf(fid, 'RT Dose Fixer - Tag Inspection Log\n');
        fprintf(fid, 'Developer: Haibin Zeng\n');
        fprintf(fid, 'Version  : 2026.10\n');
        fprintf(fid, 'Exported : %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf(fid, '========================================\n\n');
        for i = 1:length(content)
            fprintf(fid, '%s\n', content{i});
        end
        fclose(fid);
        set(txt_status, 'String', sprintf('Log exported: %s', fullfile(p, f)));
    end

    function showHelp(~, ~)
        help_txt = {
            'RT Dose Fixer - Help'
            ''
            'Eclipse mode:'
            '  - Write ReferencedRTPlanSequence pointing to Eclipse plan UID'
            '  - One-step process'
            ''
            'Monaco mode:'
            '  - Read Plan UID from Monaco-exported RT Plan file'
            '  - Read RTSS UID from Monaco-exported RTSS file'
            '  - Only modify the two reference UIDs in RTDOSE'
            '  - Character set and other tags remain unchanged'
            ''
            'Shortcuts:'
            '- Enter   : Fix RT Dose'
            '- Ctrl+E  : Export Log'
            '- Ctrl+O  : Browse Folder'
        };
        msgbox(help_txt, 'Help', 'help');
    end

    function onKeyPress(~, event)
        switch event.Key
            case 'return'
                runFix();
            case 'e'
                if ~isempty(event.Modifier) && any(strcmp(event.Modifier, 'control'))
                    exportLog();
                end
            case 'o'
                if ~isempty(event.Modifier) && any(strcmp(event.Modifier, 'control'))
                    selectDir();
                end
        end
    end

    function showSuccessDialog(source_info, output_file, plan_uid, tps)
        dlg = figure('Name', 'Success', ...
                     'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                     'Resize', 'off', 'Color', [0.96, 0.97, 0.99], ...
                     'Position', [500, 280, 620, 400]);

        uicontrol('Style', 'text', 'String', 'RT Dose Fixed Successfully!', ...
                  'HorizontalAlignment', 'center', ...
                  'FontName', 'Times New Roman', 'FontSize', 18, 'FontWeight', 'bold', ...
                  'ForegroundColor', [0.10, 0.55, 0.20], ...
                  'BackgroundColor', [0.96, 0.97, 0.99], ...
                  'Position', [20, 330, 580, 40]);

        uicontrol('Style', 'text', ...
                  'String', sprintf('Target TPS: %s', tps), ...
                  'HorizontalAlignment', 'left', ...
                  'FontName', 'Times New Roman', 'FontSize', 13, ...
                  'ForegroundColor', [0.15, 0.20, 0.30], ...
                  'BackgroundColor', [0.96, 0.97, 0.99], ...
                  'Position', [40, 275, 540, 30]);

        uicontrol('Style', 'text', ...
                  'String', sprintf('UID Source: %s', source_info), ...
                  'HorizontalAlignment', 'left', ...
                  'FontName', 'Times New Roman', 'FontSize', 12, ...
                  'ForegroundColor', [0.15, 0.20, 0.30], ...
                  'BackgroundColor', [0.96, 0.97, 0.99], ...
                  'Position', [40, 235, 540, 30]);

        uicontrol('Style', 'text', ...
                  'String', sprintf('Target Plan UID: %s', plan_uid), ...
                  'HorizontalAlignment', 'left', ...
                  'FontName', 'Times New Roman', 'FontSize', 11, ...
                  'ForegroundColor', [0.30, 0.40, 0.55], ...
                  'BackgroundColor', [0.96, 0.97, 0.99], ...
                  'Position', [40, 195, 540, 30]);

        uicontrol('Style', 'text', ...
                  'String', 'Output File:', ...
                  'HorizontalAlignment', 'left', ...
                  'FontName', 'Times New Roman', 'FontSize', 12, ...
                  'ForegroundColor', [0.15, 0.20, 0.30], ...
                  'BackgroundColor', [0.96, 0.97, 0.99], ...
                  'Position', [40, 150, 540, 25]);

        uicontrol('Style', 'text', ...
                  'String', output_file, ...
                  'HorizontalAlignment', 'left', ...
                  'FontName', 'Times New Roman', 'FontSize', 10, ...
                  'ForegroundColor', [0.20, 0.35, 0.55], ...
                  'BackgroundColor', [0.96, 0.97, 0.99], ...
                  'Position', [40, 110, 540, 40]);

        uicontrol('Style', 'pushbutton', 'String', 'Open Output Folder', ...
                  'FontName', 'Times New Roman', 'FontSize', 12, 'FontWeight', 'bold', ...
                  'ForegroundColor', [1, 1, 1], 'BackgroundColor', [0.20, 0.45, 0.75], ...
                  'Position', [40, 50, 200, 45], ...
                  'Callback', @(~,~) openFolder(fileparts(output_file)));

        uicontrol('Style', 'pushbutton', 'String', 'OK', ...
                  'FontName', 'Times New Roman', 'FontSize', 13, 'FontWeight', 'bold', ...
                  'ForegroundColor', [1, 1, 1], 'BackgroundColor', [0.20, 0.45, 0.75], ...
                  'Position', [400, 50, 140, 45], ...
                  'Callback', @(~,~) delete(dlg));
    end

    function openFolder(p)
        if ispc
            winopen(p);
        elseif ismac
            system(['open "' p '"']);
        else
            system(['xdg-open "' p '"']);
        end
    end

    function onClose(~, ~)
        try
            last_dir = get(edit_dir, 'String');
            if isMonaco()
                last_out = get(mc.edit_out, 'String');
                last_tps = 'Monaco';
                last_monaco_plan = get(mc.edit_plan, 'String');
                last_monaco_rtss = get(mc.edit_rtss, 'String');
            else
                last_out = get(ec.edit_out, 'String');
                last_tps = 'Eclipse';
            end
            save(config_file, 'last_dir', 'last_out', 'last_tps', ...
                 'last_monaco_plan', 'last_monaco_rtss');
        catch
        end
        delete(fig);
    end
end

%% ===== Scan function (filename + Modality) =====
function [plan_files, dose_files, rtss_files] = scanDicomFiles(work_dir)
    plan_files = []; dose_files = []; rtss_files = [];
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    %% Step 1: Scan by filename pattern
    % RTPLAN
    tmp = dir(fullfile(work_dir, 'RTPLAN*'));
    if isempty(tmp), tmp = dir(fullfile(work_dir, '*rtplan*')); end
    plan_files = [plan_files; tmp];

    % RT Dose
    tmp = [dir(fullfile(work_dir, 'RD*')); ...
           dir(fullfile(work_dir, 'RTDOSE*')); ...
           dir(fullfile(work_dir, '*rtdose*'))];
    dose_files = [dose_files; tmp];

    % RTSS
    tmp = [dir(fullfile(work_dir, 'RS*')); ...
           dir(fullfile(work_dir, 'RTSTRUCT*')); ...
           dir(fullfile(work_dir, '*rtss*'))];
    rtss_files = [rtss_files; tmp];

    % Record what we've found by filename
    for i = 1:length(plan_files), seen(plan_files(i).name) = true; end
    for i = 1:length(dose_files), seen(dose_files(i).name) = true; end
    for i = 1:length(rtss_files), seen(rtss_files(i).name) = true; end

    %% Step 2: Scan by Modality (for files not matched by name)
    all_files = dir(fullfile(work_dir, '*'));
    all_files = all_files(~[all_files.isdir]);

    for i = 1:length(all_files)
        fname = all_files(i).name;
        if isKey(seen, fname)
            continue;  % already found by filename
        end

        % Skip obviously non-DICOM extensions
        [~, ~, ext] = fileparts(fname);
        if ~isempty(ext) && ~any(strcmpi(ext, {'.dcm', '.dicom', ''}))
            continue;
        end

        try
            info = dicominfo(fullfile(work_dir, fname));
            if ~isfield(info, 'Modality')
                continue;
            end
            switch upper(info.Modality)
                case 'RTPLAN'
                    plan_files = [plan_files; all_files(i)];
                case 'RTDOSE'
                    dose_files = [dose_files; all_files(i)];
                case 'RTSTRUCT'
                    rtss_files = [rtss_files; all_files(i)];
            end
        catch
            continue;  % not a valid DICOM file
        end
    end

    %% Step 3: Deduplicate
    if ~isempty(plan_files)
        [~, idx] = unique({plan_files.name});
        plan_files = plan_files(idx);
    end
    if ~isempty(dose_files)
        [~, idx] = unique({dose_files.name});
        dose_files = dose_files(idx);
    end
    if ~isempty(rtss_files)
        [~, idx] = unique({rtss_files.name});
        rtss_files = rtss_files(idx);
    end
end