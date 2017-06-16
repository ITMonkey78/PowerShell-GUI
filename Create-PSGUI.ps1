# Header Information
#############################################################################################
#
#   Script: Create-PowerShellGUI.ps1
#
#   Author: Neil McGill (ITMonkey78@gmail.com)
#
#  Created: 23/05/2017
#
#    About: Build PowerShell GUIs from within another PowerShell GUI.
#           Prototype 'Powershell Form Builder' dated April 2015 from Z.Alex -
#           <https://gallery.technet.microsoft.com/scriptcenter/Powershell-Form-Builder-3bcaf2c7>
#           This version is based on modifications made by Mozers <https://bitbucket.org/Mozers.powershell-formdesigner>
#
#    Usage: This script is ran from within the powershell command shell.
#           Called by dot-sourcing the file to launch the GUI - ".\<location of ps1>\Create-PowerShellGUI.ps1"
#
  $version = "1.0.4"
#
#  History:
# 23/05/2017 - 1.0.0 - Initial release version. Pop-out Form creation and open/save options added.
# 24/05/2017 - 1.0.1 - Added editable properties for added controls. Properties are now saved with controls
# 29/05/2017 - 1.0.2 - fixed issue with resetting backcolor back to original value when selecting a control 
# 05/06/2017 - 1.0.3 - added Events for controls
# 09/06/2017 - 1.0.4 - added even more control objects (DateTimePicker, Scrollbars, MenuStrips etc)
#
# Requirements:
# Requires Powershell -Version 2 or later
#
#############################################################################################

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$Global:frmDesign = $null
$Global:CurrentCtrl = $null
$Global:CurrentBgCol = $null
$Global:Source = ''
$Global:iCurFirstX = 0
$Global:iCurFirstY = 0


# --- Resize and move control --------------------------------------
function mouseDown {
	$Global:iCurFirstX = ([System.Windows.Forms.Cursor]::Position.X)
	$Global:iCurFirstY = ([System.Windows.Forms.Cursor]::Position.Y)
}

function mouseMove ($mControlName) {
	$iCurPosX = ([System.Windows.Forms.Cursor]::Position.X)
	$iCurPosY = ([System.Windows.Forms.Cursor]::Position.Y)
	$iBorderWidth = ($Global:frmDesign.Width - $Global:frmDesign.ClientSize.Width) / 2
	$iTitlebarHeight = $Global:frmDesign.Height - $Global:frmDesign.ClientSize.Height - 2 * $iBorderWidth

	if ($Global:iCurFirstX -eq 0 -and $Global:iCurFirstY -eq 0){
		if ($this.Parent -eq 'GroupBox' -or $this.Parent -eq 'TabControl' -or $this.Parent -eq 'TabPage') {
			$GroupBoxLocationX = 0
			$GroupBoxLocationY = 0
		} else {
			$GroupBoxLocationX = $this.Parent.Location.X
			$GroupBoxLocationY = $this.Parent.Location.Y
		}
		$bIsWidthChange = ($iCurPosX - $Global:frmDesign.Location.X - $GroupBoxLocationX - $this.Location.X) -ge $this.Width
		$bIsHeightChange = ($iCurPosY - $Global:frmDesign.Location.Y - $GroupBoxLocationY - $this.Location.Y) -ge ($this.Height + $iTitlebarHeight)

		if ($bIsWidthChange -and $bIsHeightChange) {
			$this.Cursor = "SizeNWSE"
		} elseif ($bIsWidthChange) {
			$this.Cursor = "SizeWE"
		} elseif ($bIsHeightChange) {
			$this.Cursor = "SizeNS"
		} else {
			$this.Cursor = "SizeAll"
		}
	} else {
		$mDifX = $Global:iCurFirstX - $iCurPosX
		$mDifY = $Global:iCurFirstY - $iCurPosY
		switch ($this.Cursor){
			"[Cursor: SizeWE]"  {	$this.Width = $this.Width - $mDifX }
			"[Cursor: SizeNS]"  {	$this.Height = $this.Height - $mDifY }
			"[Cursor: SizeNWSE]"{
						$this.Width = $this.Width - $mDifX
						$this.Height = $this.Height - $mDifY
			}
			"[Cursor: SizeAll]" {
						$this.Left = $this.Left - $mDifX
						$this.Top = $this.Top - $mDifY
			}
		}
		$Global:iCurFirstX = $iCurPosX
		$Global:iCurFirstY = $iCurPosY
	}
}

function mouseUP {
	$this.Cursor = "SizeAll"
	$Global:iCurFirstX = 0
	$Global:iCurFirstY = 0
	ListProperties
}

function ResizeAndMoveWithKeyboard {
	if ($Global:CurrentCtrl) {
		if     ($_.KeyCode -eq 'Left'  -and $_.Modifiers -eq 'None')    {$Global:CurrentCtrl.Left   -= 1; $_.Handled = $true; ListProperties}
		elseif ($_.KeyCode -eq 'Left'  -and $_.Modifiers -eq 'Control') {$Global:CurrentCtrl.Width  -= 1; $_.Handled = $true; ListProperties}
		elseif ($_.KeyCode -eq 'Right' -and $_.Modifiers -eq 'None')    {$Global:CurrentCtrl.Left   += 1; $_.Handled = $true; ListProperties}
		elseif ($_.KeyCode -eq 'Right' -and $_.Modifiers -eq 'Control') {$Global:CurrentCtrl.Width  += 1; $_.Handled = $true; ListProperties}
		elseif ($_.KeyCode -eq 'Up'    -and $_.Modifiers -eq 'None')    {$Global:CurrentCtrl.Top    -= 1; $_.Handled = $true; ListProperties}
		elseif ($_.KeyCode -eq 'Up'    -and $_.Modifiers -eq 'Control') {$Global:CurrentCtrl.Height -= 1; $_.Handled = $true; ListProperties}
		elseif ($_.KeyCode -eq 'Down'  -and $_.Modifiers -eq 'None')    {$Global:CurrentCtrl.Top    += 1; $_.Handled = $true; ListProperties}
		elseif ($_.KeyCode -eq 'Down'  -and $_.Modifiers -eq 'Control') {$Global:CurrentCtrl.Height += 1; $_.Handled = $true; ListProperties}
		elseif ($_.KeyCode -eq 'Delete' -and $_.Modifiers -eq 'None')   {$_.Handled = $true; RemoveCurrentCtrl;}
	}
}

# --- Controls ---------------------------------------
function GetCtrlType($ctrl) {
	return $ctrl.GetType().FullName -replace "System.Windows.Forms.", ""
}

function RemoveCurrentCtrl {
#	$Global:frmDesign.Controls.Remove($Global:CurrentCtrl)
	if ($Global:CurrentCtrl -match 'System.Windows.Forms.Form,') {
		#this doesnt work but it stops errors occuring when trying to remove the form from itself
		$btnCloseForm_Click
	}else {
		$Global:CurrentCtrl.Parent.Controls.Remove($Global:CurrentCtrl)
		$Global:CurrentCtrl = $Global:frmDesign
		ListControls
		ListProperties
		ListEvents
	}
}

function SelectCurrentCtrlOnListControls {
	$dgvControls.Rows |% {if ($_.Cells[0].Value -eq $Global:CurrentCtrl.Name) {$_.Selected=$true; return}}
}

function ListControls {
	function EnumerateControls($container){
		foreach ($ctrl in $container.Controls) {
			$type = GetCtrlType $ctrl
			if ($type -eq 'GroupBox' -or $type -eq 'TabControl' -or $type -eq 'TabPage') {
				EnumerateControls $ctrl
			}
			$dgvControls.Rows.Add($ctrl.Name, $type, $ctrl)
		}
	}

	$dgvControls.Rows.Clear()
	$dgvControls.Rows.Add($Global:frmDesign.Name, 'Form', $Global:frmDesign)
	EnumerateControls $Global:frmDesign
	SelectCurrentCtrlOnListControls
}

function SetCurrentCtrl($arg){
	try {$Global:CurrentCtrl.BackColor = $Global:CurrentBgCol} catch {}
	if ($arg.GetType().FullName -eq 'System.Int32') { # click on a number of $dgvControls
		$Global:CurrentCtrl = $dgvControls.Rows[$arg].Cells[2].Value
	} else { # click on a control in $frmDesign
		$Global:CurrentCtrl = $arg
		SelectCurrentCtrlOnListControls
	}
	try {
		$Global:CurrentBgCol = $Global:CurrentCtrl.BackColor
		$Global:CurrentCtrl.BackColor = 'LightBlue'
	} catch {}
	$Global:CurrentCtrl.Focus()
	ListAvailableProperties
	ListProperties
	ListAvailableEvents
	ListEvents
}

$btnAddControl_Click = {
	function CreateNewCtrlName($ctrl_type) {
		$arrCtrlNames = $dgvControls.Rows | % {$_.Cells[0].Value}
		$num = 0
		do {
			$NewCtrlName = $ctrl_type + $num
			$num += 1
		} while ($arrCtrlNames -contains $NewCtrlName)
		return $NewCtrlName
	}

	$ctrl_type = $cbAddControl.Items[$cbAddControl.SelectedIndex]

	if ($null -ne $ctrl_type) {
		$Control = New-Object System.Windows.Forms.$ctrl_type
		$Control.Name = CreateNewCtrlName $ctrl_type
		$Control.Cursor = 'SizeAll'
		if ($ctrl_type -eq 'ComboBox' -or $ctrl_type -eq 'ListBox')    {$Control.IntegralHeight = $false}

		$defaultTags = [system.collections.arraylist]('Name','Left','Top','Width','Height')
		$Control.Tag = $defaultTags
		if (@('Button', 'CheckBox', 'GroupBox', 'Label', 'RadioButton', 'TabPage') -contains $ctrl_type) {
			$Control.Text = $Control.Name
			$Control.Tag += 'Text'
		}
		$Control.Add_PreviewKeyDown({$_.IsInputKey = $true})
		$Control.Add_KeyDown({ResizeAndMoveWithKeyboard})
		$Control.Add_MouseDown({MouseDown})
		$Control.Add_MouseMove({MouseMove})
		$Control.Add_MouseUP({MouseUP})
		$Control.Add_Click({SetCurrentCtrl $this})
		$cur_ctrl_type = GetCtrlType $Global:CurrentCtrl

		# force tabpages to only spawn within Tabcontrols
		if ($ctrl_type -eq 'TabPage') { 
			if ($cur_ctrl_type -eq 'TabControl') { 
				$Global:CurrentCtrl.Controls.Add($Control) 
			}
		} # if we have a groupbox or tabpage selected add the new element to that
		elseif ($cur_ctrl_type -eq 'GroupBox' -or $cur_ctrl_type -eq 'TabPage') {
			$Global:CurrentCtrl.Controls.Add($Control)
		} # otherwise add it directly to the form
		else {
			$Global:frmDesign.Controls.Add($Control)
			SetCurrentCtrl $Control
		}
		ListControls
	}
}

# --- Properties ---------------------------------------
function ListAvailableProperties {
	$cbAddProp.Items.Clear()
	[array]$props = $Global:CurrentCtrl | Get-Member -membertype properties
	foreach ($p in $props) {
		$cbAddProp.Items.Add($p.Name)
	}
}

function ListProperties {
	try {$dgvProps.Rows.Clear()} catch {return}
	[array]$props = $Global:CurrentCtrl | Get-Member -membertype properties
	foreach ($prop in $props) {
		$pname = $prop.Name
		if ($Global:CurrentCtrl.Tag -contains $pname) {
			$value = $Global:CurrentCtrl.$pname
		#	if ($value.GetType().FullName -eq 'System.Drawing.Font') {
		#		$value = $value.Name + ',' + $value.SizeInPoints + ',' + $value.Style
		#	}
			$value = $value -replace 'Color \[(\w+)\]', '$1'
			$dgvProps.Rows.Add($pname, $value)
		}
	}
}

function AddProperty{
	$prop_name = $cbAddProp.Items[$cbAddProp.SelectedIndex]
	$Global:CurrentCtrl.Tag += $prop_name
	ListProperties
}

function RemoveProperty($prop_name){
	try {
		if ($Global:CurrentCtrl.Tag -contains $prop_name) {$Global:CurrentCtrl.Tag = $Global:CurrentCtrl.Tag | where-Object { $_ -ne $prop_name } }
		if ($prop_name -eq 'Name') {RemoveCurrentCtrl;}
		ListProperties
	}
	catch {}
}


$dgvProps_CellEndEdit = {
	$prop_name = $dgvProps.CurrentRow.Cells[0].Value
	$value = $dgvProps.CurrentRow.Cells[1].FormattedValue

	$arrMatches = [regex]::matches($value, '^([\w ]+),\s*(\d+),\s*(\w+)$')
	if ($arrMatches.Success) {
		foreach ($m in $arrMatches) {
			$font_name = [string]$m.groups[1]
			$font_size = [string]$m.groups[2]
			$font_style = [string]$m.groups[3]
			$Global:CurrentCtrl.font = New-Object System.Drawing.Font($font_name, $font_size,[System.Drawing.FontStyle]::$font_style)
		}
 	} else {
		if ($value -eq 'True') {$value = $true}
		elseif ($value -eq 'False') {$value = $false}
		$Global:CurrentCtrl.$prop_name = $value
	}
	if ($Global:CurrentCtrl.Tag -notcontains $prop_name) {$Global:CurrentCtrl.Tag += $prop_name}
	if ($prop_name -eq 'Name') {ListControls}
	if ($prop_name -eq 'BackColor') {$Global:CurrentBgCol = $value}
	ListProperties
}

# --- Events -----------------------------------------
function ListAvailableEvents {
	$cbAddEvent.Items.Clear()
	$Global:CurrentCtrl | Get-Member | % { if ($_ -like '*EventHandler*') { $cbAddEvent.Items.Add($_.Name) } }
}

function ListEvents {
	$dgvEvent.Rows.clear()
	[array]$events = $Global:CurrentCtrl | Get-Member | ? { $_ -like '*EventHandler*' }
	foreach ($event in $events) {
		$ename = $event.Name
		if ($Global:CurrentCtrl.Tag -like "Add_$ename(*") {
			$dgvEvent.Rows.Add($ename)			
		}
	}
}

function AddEvent{
	$event_name = $cbAddEvent.Items[$cbAddEvent.SelectedIndex]
	$Global:CurrentCtrl.Tag += 'Add_' + $event_name + '($' + $Global:CurrentCtrl.Name + '_' + $event_name + ')'
	ListEvents
}

function RemoveEvent($event_name){
	try {

		if ($null -ne $event_name) {
			if ($Global:CurrentCtrl.Tag -contains 'Add_' + $event_name + '($' + $Global:CurrentCtrl.Name + '_' + $event_name + ')') {$Global:CurrentCtrl.Tag = $Global:CurrentCtrl.Tag | where-Object { $_ -ne 'Add_' + $event_name + '($' + $Global:CurrentCtrl.Name + '_' + $event_name + ')' } }
			ListEvents
		}
	}
	catch {}
}

# --- New Form ---------------------------------------
function EnableButtons{
	$btnSaveForm.Enabled = $true
	$btnAddControl.Enabled = $true
	$btnRemoveControl.Enabled = $true
	$btnAddProp.Enabled = $true
	$btnRemoveProp.Enabled = $true
	$btnAddEvent.Enabled = $true
	$btnRemoveEvent.Enabled = $true
	$btnNewForm.Enabled = $false
	$btnOpenForm.Enabled = $false
	$btnCloseForm.Enabled = $true
}

function DisableButtons{
	$btnSaveForm.Enabled = $false
	$btnAddControl.Enabled = $false
	$btnRemoveControl.Enabled = $false
	$btnAddProp.Enabled = $false
	$btnRemoveProp.Enabled = $false
	$btnAddEvent.Enabled = $false
	$btnRemoveEvent.Enabled = $false
	$btnNewForm.Enabled = $true
	$btnOpenForm.Enabled = $true
	$btnCloseForm.Enabled = $false
}

$btnNewForm_Click = {
	$Global:frmDesign = New-Object System.Windows.Forms.Form
	$Global:frmDesign.Name = 'Form0'
	$Global:frmDesign.Text = 'Form0'
	$Global:frmDesign.Tag = @('Name','Width','Height','Text')
	$Global:frmDesign.Add_ResizeEnd({ListProperties})
	$Global:frmDesign.Add_FormClosing({$_.Cancel = $true})
	$Global:frmDesign.Show()
	$Global:CurrentCtrl = $Global:frmDesign
	ListControls
	ListAvailableProperties
	ListProperties
	ListAvailableEvents
	ListEvents
	EnableButtons
}

# --- Save Form ---------------------------------------
function GetFilename($dlg_name)  {
	[system.reflection.assembly]::LoadwithPartialName("Presentationframework") | out-null
	$Dialog = New-Object Microsoft.Win32.$dlg_name
	$Dialog.Filter = "Powershell Script (*.ps1)|*.ps1|All files (*.*)|*.*"
	$Dialog.ShowDialog() | Out-Null
	return $Dialog.filename
}

$btnSaveForm_Click = {
	function EnumerateSaveControls ($container){
		$newline = "`r`n"
		$Global:Source += '#' + $newline + '#' + $container.Name + $newline + '#' + $newline
		$ctrl_type = GetCtrlType $container
		$Global:Source += '$' + $container.Name + ' = New-Object System.Windows.Forms.' + $ctrl_type + $newline
		$left = 0; $top = 0; $width = 0; $height = 0;
		[array]$props = $container | Get-Member -membertype properties
		foreach ($prop in $props) {
			$pname = $prop.Name
			if ($container.Tag -contains $pname -and $pname -ne "Name") {
				if     ($pname -eq "Left")   {$left = $container.Left}
				elseif ($pname -eq "Top")    {$top = $container.Top}
				elseif ($pname -eq "Width")  {$width = $container.Width}
				elseif ($pname -eq "Height") {$height = $container.Height}
				else {
					$value = $container.$pname
					if ($value.GetType().FullName -eq 'System.Drawing.Font') {
						$font_name = $value.Name
						$font_size = $value.SizeInPoints
						$font_style = $value.Style
						$value = 'New-Object System.Drawing.font("' + $font_name + '",' + $font_size + ', [System.Drawing.FontStyle]::' + $font_style + ')'
					} else {
						$value = $value -replace 'True', '$true' -replace 'False', '$false' -replace 'Color \[(\w+)\]', '$1'
						if ($value -ne '$true' -and $value -ne '$false') { $value = '"' + $value + '"' }
					}
					$Global:Source += '$' + $container.Name + '.' + $pname + ' = ' + $value + $newline
				}
			}
		}

		foreach ($event in $container.Tag) {
			if ($event -like "Add_*") { $Global:source += '$' + $container.Name + '.' + $event + $newline }
		}

		if ($ctrl_type -eq 'Form') {
			$width = $container.ClientSize.Width
			$height = $container.ClientSize.Height
			$Global:Source += '$' + $container.Name + '.ClientSize = New-Object System.Drawing.Size(' + $width + ', ' + $height + ')' + $newline
		} else {
			if ($width -ne 0 -and $height -ne 0) {
				$Global:Source += '$' + $container.Name + '.Size = New-Object System.Drawing.Size(' + $width + ', ' + $height + ')' + $newline
			}

			$Global:Source += '$' + $container.Name + '.Location = New-Object System.Drawing.Point(' + $left + ', ' + $top + ')' + $newline
			$Global:Source += '$' + $container.Parent.Name + '.Controls.Add($' + $container.Name + ')' + $newline + $newline
		}
		if ($ctrl_type -eq 'Form' -or $ctrl_type -eq 'GroupBox' -or $ctrl_type -eq 'TabPage') {
			foreach ($ctrl in $container.Controls) {
				EnumerateSaveControls $ctrl
			}
		}
	}

	$newline = "`r`n"
	$Global:Source  = 'Add-Type -AssemblyName System.Windows.Forms' + $newline
	$Global:Source += 'Add-Type -AssemblyName System.Drawing' + $newline
	$Global:Source += '[Windows.Forms.Application]::EnableVisualStyles()' + $newline + $newline

	EnumerateSaveControls $Global:frmDesign

	$Global:Source += '[void]$' + $Global:frmDesign.Name + '.ShowDialog()' + $newline
	$filename = ''
	$filename = GetFilename 'SaveFileDialog'
	if ($filename -notlike '') {$Global:Source > $filename}
}

# --- Open Existing Form ---------------------------------------
$btnOpenForm_Click = {
	function SetControlTag($ctrl){ # find the feature controls that were specified in the code and add them to $ctrl.Tag
		$pattern = '(.*)\$' + $ctrl.Name + '\.(\w+)\s*='
		$arrMatches = [regex]::matches($Global:Source, $pattern)
		$arrTags = @()
		foreach ($m in $arrMatches) {
			[string]$comment = $m.Groups[1]
			if (-not $comment.Contains('#')) {
				$prop_name = [string]$m.Groups[2]
				if ($prop_name) {
					if ($prop_name -eq 'Location') {$arrTags += @('Left','Top')}
					elseif ($prop_name -eq 'Size' -or $prop_name -eq 'ClientSize') {$arrTags += @('Width','Height')}
					else {$arrTags += $prop_name}
				}
			}
		}
		if ($arrTags -notcontains 'Name') {$arrTags += 'Name'}
		$ctrl.Tag = $arrTags
	}

	function EnumerateLoadControls($container) {
		foreach ($ctrl in $container.Controls) {
			SetControlTag $ctrl
			$ctrl_type = GetCtrlType $ctrl
			if ($ctrl_type -eq 'GroupBox') {
				EnumerateLoadControls $ctrl
			}
			if (($ctrl_type -eq 'ComboBox') -or ($ctrl_type -eq 'ListBox'))  {$ctrl.IntegralHeight = $false}
			elseif ($ctrl_type -ne 'WebBrowser') {
				$ctrl.Cursor = 'SizeAll'
				$ctrl.Add_PreviewKeyDown({$_.IsInputKey = $true})
				$ctrl.Add_KeyDown({ResizeAndMoveWithKeyboard})
				$ctrl.Add_MouseDown({MouseDown})
				$ctrl.Add_MouseMove({MouseMove})
				$ctrl.Add_MouseUP({MouseUP})
				$ctrl.Add_Click({SetCurrentCtrl $this})
			}
		}
	}

	$filename = GetFilename 'OpenFileDialog'
	if ($filename -notlike ''){
		$Global:Source = get-content $filename | Out-String
		# Analysis of code text - Search form
		$pattern = '(.*)\$(\w+)\s*=\s*New\-Object\s+(System\.)?Windows\.Forms\.Form'
		$arrMatches = [regex]::matches($Global:Source, $pattern)
		foreach ($m in $arrMatches) {
			[string]$comment = $m.Groups[1]
			if (-not $comment.Contains('#')) {
				$form_name = $m.Groups[2]
			}
		}
		if ($form_name) { # if the text could not find the name of the form
			$find = '\$' + $form_name + '\.Show(Dialog)?\(\)'
			$Global:Source = $Global:Source -replace $find, '' # remove the line of its launch so it doesnt load

			Invoke-Expression -Command $Global:Source # Execute a form containing code

			try {$Global:frmDesign = Get-Variable -ValueOnly $form_name} catch {} # Looking up PowerShell variables in the form
			if ($Global:frmDesign) {
				# Adding all the controls on the form with property Name equal to the variable name
				Get-Variable | where {[string]$_.Value -like 'System.Windows.Forms.*'} | where {try {$_.Value.Name = $_.Name} catch {}}

				# Set the desired properties of the opening event, and all the controls on a form
				EnumerateLoadControls $Global:frmDesign
				# And the form itself
				$Global:frmDesign.Name = $form_name
				SetControlTag $Global:frmDesign
				$Global:frmDesign.Add_ResizeEnd({ListProperties})
				$Global:frmDesign.Add_FormClosing({$_.Cancel = $true}) # Dont allow closing of the form by clicking top-right 'X'
				$Global:frmDesign.Show()

				$Global:CurrentCtrl = $Global:frmDesign
				ListControls
				ListAvailableProperties
				ListProperties
				ListAvailableEvents
				ListEvents
				EnableButtons
			} else {
				$message = "Can't find variable $" + $form_name + "`nPlease open ONLY SOURCE OF FORM.`nExclude other code."
				[System.Windows.Forms.MessageBox]::Show($message, 'Error to open exist Form', 'OK', 'Error')
			}
		} else {
			$message = 'Your code not contain any form!'
			[System.Windows.Forms.MessageBox]::Show($message, 'Error to open exist Form', 'OK', 'Error')
		}
	}
}

# --- Close Existing Form ---------------------------------------
$btnCloseForm_Click = {
	DisableButtons
	$dgvControls.Rows.Clear()
	$dgvProps.Rows.Clear()
	$Global:frmDesign.Add_FormClosing({$_.Cancel = $false})
	$Global:frmDesign.Close()
	$Global:frmDesign = $null
}

# --- Create and Show Main Window -------------------------------
function ShowMainWindow {
	#
	#btnNewForm
	#
	$btnNewForm = New-Object System.Windows.Forms.Button
	$btnNewForm.Location = New-Object System.Drawing.Point(12, 12)
	$btnNewForm.Size = New-Object System.Drawing.Size(88, 23)
	$btnNewForm.Text = "New Form"
	$btnNewForm.Add_Click($btnNewForm_Click)
	#
	#btnOpenForm
	#
	$btnOpenForm = New-Object System.Windows.Forms.Button
	$btnOpenForm.Location = New-Object System.Drawing.Point(114, 12)
	$btnOpenForm.Size = New-Object System.Drawing.Size(88, 23)
	$btnOpenForm.Text = "Open Form"
	$btnOpenForm.Add_Click($btnOpenForm_Click)
	#
	#btnSaveForm
	#
	$btnSaveForm = New-Object System.Windows.Forms.Button
	$btnSaveForm.Location = New-Object System.Drawing.Point(216, 12)
	$btnSaveForm.Size = New-Object System.Drawing.Size(88, 23)
	$btnSaveForm.Text = "Save Form"
	$btnSaveForm.Enabled = $false
	$btnSaveForm.Add_Click($btnSaveForm_Click)
	#
	#btnCloseForm
	#
	$btnCloseForm = New-Object System.Windows.Forms.Button
	$btnCloseForm.Location = New-Object System.Drawing.Point(318, 12)
	$btnCloseForm.Size = New-Object System.Drawing.Size(88, 23)
	$btnCloseForm.Text = "Close Form"
	$btnCloseForm.Enabled = $false
	$btnCloseForm.Add_Click($btnCloseForm_Click)
	#
	#btnExitForm
	#
	$btnExitForm = New-Object System.Windows.Forms.Button
	$btnExitForm.Location = New-Object System.Drawing.Point(518, 12)
	$btnExitForm.Size = New-Object System.Drawing.Size(88, 23)
	$btnExitForm.Text = "Exit"
	$btnExitForm.Enabled = $true
	$btnExitForm.Add_Click({$frmPSFD.Close();})
	# --------------------------------------------------------
	#cbAddControl
	#
	$cbAddControl = New-Object Windows.Forms.ComboBox
	$cbAddControl.Location = New-Object System.Drawing.Point(8, 14)
	$cbAddControl.Size = New-Object System.Drawing.Size(122, 21)
        $null = $cbAddControl.Items.Add("BindingNavigator")
        $null = $cbAddControl.Items.Add("Button")
        $null = $cbAddControl.Items.Add("CheckBox")
        $null = $cbAddControl.Items.Add("CheckedListBox")
        $null = $cbAddControl.Items.Add("ComboBox")
        $null = $cbAddControl.Items.Add("DataGridView")
        $null = $cbAddControl.Items.Add("DateTimePicker")
        $null = $cbAddControl.Items.Add("DomainUpDown")
        $null = $cbAddControl.Items.Add("FlowLayoutPanel")
        $null = $cbAddControl.Items.Add("GroupBox")
        $null = $cbAddControl.Items.Add("HScrollBar")
        $null = $cbAddControl.Items.Add("ImageList")
        $null = $cbAddControl.Items.Add("Label")
        $null = $cbAddControl.Items.Add("LinkLabel")
        $null = $cbAddControl.Items.Add("ListBox")
        $null = $cbAddControl.Items.Add("ListView")
        $null = $cbAddControl.Items.Add("ListViewItem")
        $null = $cbAddControl.Items.Add("MaskedTextBox")
        $null = $cbAddControl.Items.Add("MenuStrip")
        $null = $cbAddControl.Items.Add("MonthCalendar")
        $null = $cbAddControl.Items.Add("NumericUpDown")
        $null = $cbAddControl.Items.Add("Panel")
        $null = $cbAddControl.Items.Add("PictureBox")
        $null = $cbAddControl.Items.Add("PrintPreviewControl")
        $null = $cbAddControl.Items.Add("ProgressBar")
        $null = $cbAddControl.Items.Add("PropertyGrid")
        $null = $cbAddControl.Items.Add("RadioButton")
        $null = $cbAddControl.Items.Add("RichTextBox")
        $null = $cbAddControl.Items.Add("SplitContainer")
        $null = $cbAddControl.Items.Add("Splitter")
        $null = $cbAddControl.Items.Add("StatusStrip")
        $null = $cbAddControl.Items.Add("TabControl")
        $null = $cbAddControl.Items.Add("TabPage")
        $null = $cbAddControl.Items.Add("TableLayoutPanel")
        $null = $cbAddControl.Items.Add("TextBox")
        $null = $cbAddControl.Items.Add("Timer")
        $null = $cbAddControl.Items.Add("ToolStrip")
        $null = $cbAddControl.Items.Add("ToolStripMenuItem")
        $null = $cbAddControl.Items.Add("ToolTip")
        $null = $cbAddControl.Items.Add("TrackBar")
        $null = $cbAddControl.Items.Add("TreeView")
        $null = $cbAddControl.Items.Add("VScrollBar")
	#
	#btnAddControl
	#
	$btnAddControl = New-Object System.Windows.Forms.Button
	$btnAddControl.Location = New-Object System.Drawing.Point(136, 13)
	$btnAddControl.Size = New-Object System.Drawing.Size(58, 23)
	$btnAddControl.Text = "Add"
	$btnAddControl.Add_Click($btnAddControl_Click)
	$btnAddControl.Enabled = $false
	#
	#btnRemoveControl
	#
	$btnRemoveControl = New-Object System.Windows.Forms.Button
	$btnRemoveControl.Location = New-Object System.Drawing.Point(196, 13)
	$btnRemoveControl.Size = New-Object System.Drawing.Size(58, 23)
	$btnRemoveControl.Text = "Remove"
	$btnRemoveControl.Enabled = $false
	$btnRemoveControl.Add_Click({RemoveCurrentCtrl})
	#
	#lblTooltipCtrl
	#
	$lblTooltipCtrl = New-Object System.Windows.Forms.Label
	$lblTooltipCtrl.Text = "Use Arrow keys and Ctrl to move and resize"
	$lblTooltipCtrl.Location = New-Object System.Drawing.Point(6, 41)
	$lblTooltipCtrl.Size = New-Object System.Drawing.Size(245, 16)
	$lblTooltipCtrl.Enabled = $false
	#
	#lvControls
	#
	$dgvControls = New-Object System.Windows.Forms.DataGridView
	$dgvControls.Location = New-Object System.Drawing.Point(6, 63)
	$dgvControls.Size = New-Object System.Drawing.Size(248, 437)
	$dgvControls.BackGroundColor = "White"
	$null = $dgvControls.Columns.Add("", "Name")
	$null = $dgvControls.Columns.Add("", "Type")
	$null = $dgvControls.Columns.Add("", "LinkToControl")
	$dgvControls.Columns[0].Width = 159
	$dgvControls.Columns[1].Width = 86
	$dgvControls.Columns[2].Width = 0
	$dgvControls.Columns[0].ReadOnly = $true
	$dgvControls.Columns[1].ReadOnly = $true
	$dgvControls.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
	$dgvControls.RowHeadersVisible = $false
	$dgvControls.MultiSelect = $false
	$dgvControls.ScrollBars = 'Vertical'
	$dgvControls.SelectionMode = 'FullRowSelect'
	$dgvControls.AllowUserToResizeRows = $false
	$dgvControls.AllowUserToAddRows = $false
	$dgvControls.Add_CellClick({SetCurrentCtrl $dgvControls.CurrentRow.Index})
	#
	#gbControls
	#
	$gbControls = New-Object Windows.Forms.GroupBox
	$gbControls.Controls.Add($dgvControls)
	$gbControls.Controls.Add($btnRemoveControl)
	$gbControls.Controls.Add($cbAddControl)
	$gbControls.Controls.Add($btnAddControl)
	$gbControls.Controls.Add($lblTooltipCtrl)
	$gbControls.Location = New-Object System.Drawing.Point(10, 41)
	$gbControls.Size = New-Object System.Drawing.Size(262, 503)
	$gbControls.Text = "Controls:"
	#--------------------------------------------------------
	#cbAddProp
	#
	$cbAddProp = New-Object Windows.Forms.ComboBox
	$cbAddProp.Location = New-Object System.Drawing.Point(6, 14)
	$cbAddProp.Size = New-Object System.Drawing.Size(189, 21)
	#
	#btnAddProp
	#
	$btnAddProp = New-Object System.Windows.Forms.Button
	$btnAddProp.Location = New-Object System.Drawing.Point(201, 13)
	$btnAddProp.Size = New-Object System.Drawing.Size(58, 23)
	$btnAddProp.Text = "Add"
	$btnAddProp.Add_Click({AddProperty })
	$btnAddProp.Enabled = $false
	#
	#btnRemoveProp
	#
	$btnRemoveProp = New-Object System.Windows.Forms.Button
	$btnRemoveProp.Location = New-Object System.Drawing.Point(261, 13)
	$btnRemoveProp.Size = New-Object System.Drawing.Size(58, 23)
	$btnRemoveProp.Text = "Remove"
	$btnRemoveProp.Add_Click({if ($dgvProps.Rows.Count -gt 0) { RemoveProperty $dgvProps.CurrentRow.Cells[0].value }})
	$btnRemoveProp.Enabled = $false
	#
	#
	#lblTooltip
	#
	$lblTooltipProp = New-Object System.Windows.Forms.Label
	$lblTooltipProp.Text = "Removing a property or event does not reset its value"
	$lblTooltipProp.Location = New-Object System.Drawing.Point(6, 41)
	$lblTooltipProp.Size = New-Object System.Drawing.Size(275, 16)
	$lblTooltipProp.Enabled = $false
	#
	#dgvProps
	#
	$dgvProps = New-Object System.Windows.Forms.DataGridView
	$dgvProps.Location = New-Object System.Drawing.Point(6, 63)
	$dgvProps.Size = New-Object System.Drawing.Size(313, 278)
	$dgvProps.BackGroundColor = "White"
	$null = $dgvProps.Columns.Add("", "Property")
	$null = $dgvProps.Columns.Add("", "Value")
	$dgvProps.Columns[0].Width = 109
	$dgvProps.Columns[1].Width = 200
	$dgvProps.Columns[0].ReadOnly = $true
	$dgvProps.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
	$dgvProps.RowHeadersVisible = $false
	$dgvProps.AllowUserToResizeRows = $false
	$dgvProps.AllowUserToAddRows = $false
	$dgvProps.Add_CellEndEdit($dgvProps_CellEndEdit)
	#
	#gbProps
	#
	$gbProps = New-Object Windows.Forms.GroupBox
	$gbProps.Controls.Add($cbAddProp)
	$gbProps.Controls.Add($btnAddProp)
	$gbProps.Controls.Add($btnRemoveProp)
	$gbProps.Controls.Add($lblTooltipProp)
	$gbProps.Controls.Add($dgvProps)
	$gbProps.Location = New-Object System.Drawing.Point(278, 41)
	$gbProps.Size = New-Object System.Drawing.Size(328, 353)
	$gbProps.Text = 'Properties:'
	#--------------------------------------------------------
	#cbAddEvent
	#
	$cbAddEvent = New-Object Windows.Forms.ComboBox
	$cbAddEvent.Location = New-Object System.Drawing.Point(6, 14)
	$cbAddEvent.Size = New-Object System.Drawing.Size(189, 21)
	#
	#btnAddEvent
	#
	$btnAddEvent = New-Object System.Windows.Forms.Button
	$btnAddEvent.Location = New-Object System.Drawing.Point(201, 13)
	$btnAddEvent.Size = New-Object System.Drawing.Size(58, 23)
	$btnAddEvent.Text = "Add"
	$btnAddEvent.Add_Click({AddEvent })
	$btnAddEvent.Enabled = $false
	#
	#btnRemoveEvent
	#
	$btnRemoveEvent = New-Object System.Windows.Forms.Button
	$btnRemoveEvent.Location = New-Object System.Drawing.Point(261, 13)
	$btnRemoveEvent.Size = New-Object System.Drawing.Size(58, 23)
	$btnRemoveEvent.Text = "Remove"
	$btnRemoveEvent.Add_Click({if ($dgvEvent.Rows.Count -gt 0 ) { RemoveEvent $dgvEvent.CurrentRow.Cells[0].value }})
	$btnRemoveEvent.Enabled = $false
	#
	#dgvEvent
	#
	$dgvEvent = New-Object System.Windows.Forms.DataGridView
	$dgvEvent.Location = New-Object System.Drawing.Point(6, 45)
	$dgvEvent.Size = New-Object System.Drawing.Size(313, 94)
	$dgvEvent.BackGroundColor = "White"
	$null = $dgvEvent.Columns.Add("","Event")
	$dgvEvent.Columns[0].Width = 309
	$dgvEvent.Columns[0].ReadOnly = $false
	$dgvEvent.ColumnHeadersVisible = $false
	$dgvEvent.RowHeadersVisible = $false
	$dgvEvent.AllowUserToResizeRows = $false
	$dgvEvent.AllowUserToAddRows = $false
	$dgvEvent.Add_CellEndEdit($dgvEvent_CellEndEdit)
	#
	#gbEvent
	#
	$gbEvent = New-Object Windows.Forms.GroupBox
	$gbEvent.Controls.Add($cbAddEvent)
	$gbEvent.Controls.Add($btnAddEvent)
	$gbEvent.Controls.Add($btnRemoveEvent)
	$gbEvent.Controls.Add($dgvEvent)
	$gbEvent.Location = New-Object System.Drawing.Point(278, 397)
	$gbEvent.Size = New-Object System.Drawing.Size(328, 147)
	$gbEvent.Text = 'Event Handlers:'

	#--------------------------------------------------------
	#frmPSFD
	#
	$frmPSFD = New-Object System.Windows.Forms.Form
	$frmPSFD.ClientSize = New-Object System.Drawing.Size(617, 549)
	$frmPSFD.FormBorderStyle = 'Fixed3D'
	$frmPSFD.MaximizeBox = $false
	$frmPSFD.BackgroundImageLayout = "None"
	$frmPSFD.BackColor = "White"
	$frmPSFD.Controls.Add($gbEvent)
	$frmPSFD.Controls.Add($gbProps)
	$frmPSFD.Controls.Add($gbControls)
	$frmPSFD.Controls.Add($btnExitForm)
	$frmPSFD.Controls.Add($btnSaveForm)
	$frmPSFD.Controls.Add($btnOpenForm)
	$frmPSFD.Controls.Add($btnCloseForm)
	$frmPSFD.Controls.Add($btnNewForm)
	$frmPSFD.Text = 'PowerShell Custom Forms Designer ' + $Version

	[void]$frmPSFD.ShowDialog()
}
ShowMainWindow
