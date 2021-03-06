
#generate PSObject to provide the maze functionality
function New-Maze($rows,$cols,$cellSize){
	$newMaze="" | select Cells,Opposite,Directions,TotalRows,TotalColumns,cellSize
	$newMaze.TotalRows=$rows
	$newMaze.TotalColumns=$cols
	$newMaze.cellSize=$cellSize
	$newMaze.Directions=@"
      	Up = 1
	    Down = 2
	    Right = 4
	    Left = 8
"@	| ConvertFrom-StringData

	$newMaze.Opposite=@"
	Up=Down
	Down=Up
	Right=Left
	Left=Right
"@ | ConvertFrom-StringData
	
	$sb={
		param($y,$x,$direction)
		switch($direction){
			"UP"	{return ($y-1),$x}
			"Down"	{return ($y+1),$x}
			"Left"	{return $y,($x-1)}
			"Right"	{return $y,($x+1)}
		}
	}
	$newMaze | Add-Member -MemberType ScriptMethod -Name "Move" -value $sb
	
	$sb={
		param($rows,$cols)
		$this.Cells=new-object 'Windows.Forms.PictureBox[,]' $rows, $cols   
		for ($row = 0; $row -lt $rows; $row++){
		    for ($col = 0; $col -lt $cols; $col++){
		        $this.Cells[$row, $col] = New-Object 'Windows.Forms.PictureBox'
				#calculate size and location
	            $xPosition = ($col * $this.cellSize) + 13 #padding from left
	            $yPosition = ($row * $this.cellSize) + 45 #padding from top
	            $this.Cells[$row, $col].SetBounds($xPosition, $yPosition, $this.cellSize, $this.cellSize)
				#mark start and finish
				if (($col -eq 0 -and $row -eq 0) -or ($col -eq $this.TotalColumns - 1 -and $row -eq $this.TotalRows - 1)){
					$this.Cells[$row, $col].BackColor = [Drawing.Color]::Black
				}
	            else{
	                $this.Cells[$row, $col].BackColor = [Drawing.Color]::White
	            }
				$form1.Controls.Add(($this.Cells[$row, $col]))
			}
		}
		$this.Cells=$this.Cells
	}
    $newMaze | Add-Member -MemberType ScriptMethod -Name "Initialize" -value $sb
	
	$sb={
		#reset all cells
	    for ($row = 0; $row -lt $this.TotalRows; $row++){
	        for ($col = 0; $col -lt $this.TotalColumns; $col++){
				$this.Cells[$row, $col].remove_Paint($PictureBox_OnPaintVertical)
				$this.Cells[$row, $col].remove_Paint($PictureBox_OnPaintHorizontal)
				$this.Cells[$row, $col].remove_Paint($PictureBox_OnPaintPath)
	            $this.Cells[$row, $col].BackColor = [Drawing.Color]::White
				$this.Cells[$row, $col].Tag= ""
	        }
	    }
		$form1.Refresh()
	}
	$newMaze | Add-Member -MemberType ScriptMethod -Name "Reset" -value $sb
	
	$sb={
		function CarvePassages($currentX, $currentY){
			function IsOutOfBounds($x,$y){
	            if ($x -lt 0 -or $x -gt $this.TotalColumns - 1){
	                    return $true
				}
                if ($y -lt 0 -or $y -gt $this.TotalRows - 1){
                    return $true
				}
                return $false
        	}
			#pick a random direction
            $directions = "Up","Down","Right","Left" | Get-Random -Count 4
            foreach ($direction in $directions){
                $nextY,$nextX = $this.Move($currentY,$currentX,$direction)
                if ( (IsOutOfBounds $nextX $nextY)){
                    continue
				}

                if ($this.Cells[$nextY, $nextX].Tag -ne ""){ #has been visited
                    continue
				}
				#set the walls to be knocked down
                $this.Cells[$currentY, $currentX].Tag = [int]$this.Cells[$currentY, $currentX].Tag + $this.Directions["$direction"]
                $this.Cells[$nextY, $nextX].Tag = [int]$this.Cells[$nextY, $nextX].Tag + $this.Directions[$($this.Opposite["$direction"])]

                CarvePassages $nextX $nextY
            }
        }
		#start at upper left hand corner of the grid
		$this.Reset()
        CarvePassages 0 0 
		#mark start and finish
		$this.Cells[0,0].BackColor = [Drawing.Color]::Black
		$this.Cells[($this.TotalRows-1),($this.TotalColumns-1)].BackColor = [Drawing.Color]::Black
		
    }
	$newMaze | Add-Member -MemberType ScriptMethod -Name "Generate" -value $sb
	
	$sb={
		for ($row = 0; $row -lt $this.TotalRows; $row++){
            for ($col = 0; $col -lt $this.TotalColumns; $col++){
                $removedWalls = $this.Cells[$row, $col].Tag
                if(-not(($this.Directions.Values | where { $_ -band $removedWalls }) -contains $this.Directions.Down)) {
					$this.Cells[$row,$col].add_Paint($PictureBox_OnPaintHorizontal)
				}
				if(-not(($this.Directions.Values | where { $_ -band $removedWalls }) -contains $this.Directions.Right)) {
					$this.Cells[$row,$col].add_Paint($PictureBox_OnPaintVertical)
				}
            }
     	}
	 	$form1.Refresh()
	}
	$newMaze | Add-Member -MemberType ScriptMethod -Name "Draw" -value $sb
	$script:count=0
	$script:sbSolve={
		param($xPos, $yPos,$direction)
		function isFree($xPos,$yPos,$direction){
			$removedWalls=$this.Cells[$yPos,$xPos].Tag
			if(!$removedWalls -or (($this.Directions.Values | where { $_ -band $removedWalls }) -contains $this.Directions.$direction)) {
					return $true
			}
			return $false
		}
		#Check if at finish
		if ($xPos -eq $this.TotalColumns-1 -and $yPos -eq $this.TotalRows-1){
	        return $true
	    }
		#Check for out of boundaries
	    if ($xPos -ge $this.TotalColumns -or $xPos -lt 0 -or $yPos -ge $this.TotalRows -or $yPos -lt 0){
	        return $false
		}
		#has been already searched?
		if ($script:alreadySearched[$yPos,$xPos]){
	       	return $false
		}
		#mark tile as searched
	    $script:alreadySearched[$yPos,$xPos] = $true
		foreach ($direction in ("Right","Down","Left","Up")){
			if ((isFree $xPos $yPos $direction)){
				$nextY,$nextX=$this.Move($yPos,$xPos,$direction)
				#recursive call
				if ((&$sbSolve $nextX $nextY $direction)){
					#mark the path
					$this.Cells[$nextY, $nextX].add_paint($PictureBox_OnPaintPath)
					$form1.Refresh()
					return $true
				}
			}
		}
		#unmark tile
		#$script:alreadySearched[$yPos, $xPos]=$false
	    return $false
	}
	$newMaze | Add-Member -MemberType ScriptMethod -Name "Solve" -value $sbSolve
	
	$newMaze.Initialize($rows,$cols)
	return $newMaze
}

function GenerateSolveMaze {
     <#    
        .SYNOPSIS
            Function to generate a GUI (Windows forms) to build and solve random mazes
        .DESCRIPTION
           Just a fun programming excercise
	    .PARAMETER XDimension
		    Number of columns of the maze. Defaults to 15
	    .PARAMETER YDimension
		    Number of rows of the maze. Defaults to 12
        .PARAMETER CellSize
            Cellsize of the start and end cells of the maze. Defaults to 30.
	    .EXAMPLE
		   GenerateSolveMaze
    #>
    [CmdletBinding()]
    param (
        [int]$YDimension =12,
        [int]$XDimension = 15,
        [int]$CellSize = 30
    )
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form1 = New-Object System.Windows.Forms.Form
    $label2 = New-Object System.Windows.Forms.Label
    $label1 = New-Object System.Windows.Forms.Label
    $pbBlack = New-Object System.Windows.Forms.PictureBox
    $pbWhite = New-Object System.Windows.Forms.PictureBox
    $btnReset = New-Object System.Windows.Forms.Button
    $btnSolve = New-Object System.Windows.Forms.Button
    $btnGenerate = New-Object System.Windows.Forms.Button
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState

    #region event handler
    $btnSolve_OnClick= {
	    $script:alreadySearched= new-object 'bool[,]' $maze.TotalRows,$maze.TotalColumns
	    if(!($maze.Solve(0,0,"Right"))){
		     [Windows.Forms.MessageBox]::Show("Maze can not be solved.")
	    }
    }

    $btnGenerate_OnClick= {	
	    $maze.Generate()
	    $maze.Draw()
    }

    #this=s; e=$_
    $PictureBox_OnPaintVertical={
	    $mypen = new-object Drawing.Pen black
	    $mypen.Width=1
        $_.Graphics.DrawLine($mypen,$this.ClientSize.Width-1, 0, $this.ClientSize.Width-1, $this.ClientSize.Height)
    }

    $PictureBox_OnPaintPath={
	    $mypen = new-object Drawing.Pen black
	    $mypen.Width=.2
        $_.Graphics.DrawLine($mypen,$this.ClientSize.Width/2-2, $this.ClientSize.Height/2+2, $this.ClientSize.Width/2+2, $this.ClientSize.Height/2-2)
        $_.Graphics.DrawLine($mypen,$this.ClientSize.Width/2+2, $this.ClientSize.Height/2+2, $this.ClientSize.Width/2-2, $this.ClientSize.Height/2-2)
    }

    $PictureBox_OnPaintHorizontal={
        $mypen = new-object Drawing.Pen black
	    $mypen.Width=1
        $_.Graphics.DrawLine($mypen,0, $this.ClientSize.Height-1, $this.ClientSize.Width, $this.ClientSize.Height-1)
    }


    $OnLoadForm_StateCorrection={#Correct the initial state of the form to prevent the .Net maximized form issue
	    $form1.WindowState = $InitialFormWindowState
	    $script:maze=New-Maze $yDimension $xDimension $cellSize
    }
    #endregion

    #region Generated Form Code
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 423
    $System_Drawing_Size.Width = 494
    $form1.ClientSize = $System_Drawing_Size
    $form1.DataBindings.DefaultDataSourceUpdateMode = 0
    $form1.Name = "form1"
    $form1.Text = "Maze Generator and Solver"

    $label2.DataBindings.DefaultDataSourceUpdateMode = 0
    $label2.Font = New-Object System.Drawing.Font("Microsoft Sans Serif",9.75,0,3,0)


    $btnSolve.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 2
    $System_Drawing_Point.Y = 12
    $btnSolve.Location = $System_Drawing_Point
    $btnSolve.Name = "btnSolve"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 25
    $System_Drawing_Size.Width = 55
    $btnSolve.Size = $System_Drawing_Size
    $btnSolve.TabIndex = 0
    $btnSolve.Text = "Solve"
    $btnSolve.UseVisualStyleBackColor = $True
    $btnSolve.add_Click($btnSolve_OnClick)
    $form1.Controls.Add($btnSolve)

    $btnGenerate.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 63
    $System_Drawing_Point.Y = 12
    $btnGenerate.Location = $System_Drawing_Point
    $btnGenerate.Name = "btnGenerate"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 25
    $System_Drawing_Size.Width = 120
    $btnGenerate.Size = $System_Drawing_Size
    $btnGenerate.TabIndex = 2
    $btnGenerate.Text = "Generate Maze"
    $btnGenerate.UseVisualStyleBackColor = $True
    $btnGenerate.add_Click($btnGenerate_OnClick)
    $form1.Controls.Add($btnGenerate)

    #endregion Generated Form Code

    #Save the initial state of the form
    $InitialFormWindowState = $form1.WindowState
    #Init the OnLoad event to correct the initial state of the form
    $form1.add_Load($OnLoadForm_StateCorrection)
    #Show the Form
    $form1.ShowDialog()| Out-Null

} #End Function



