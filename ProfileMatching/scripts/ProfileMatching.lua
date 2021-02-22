--Start of Global Scope---------------------------------------------------------

print('AppEngine Version: ' .. Engine.getVersion())

local helper = require 'helpers'

local GREEN = {0, 200, 0}
local RED = {200, 0, 0}
local FILL_ALPHA = 100

local MM_TO_PROCESS = 10 --10mm slices

local DELAY = 150

-- Create viewers
local v2D = View.create('Viewer2D')
local v3D = View.create('Viewer3D')

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

local function main()
  local heightMap = Object.load('resources/heightMap.json')
  local minZ, maxZ = Image.getMinMax(heightMap)
  local zRange = maxZ - minZ
  local pixelSizeX, pixelSizeY = Image.getPixelSize(heightMap)
  local heightMapW, heightMapH = Image.getSize(heightMap)

  local deco3D = View.ImageDecoration.create()
  deco3D:setRange(heightMap:getMin(), heightMap:getMax() / 1.01)

  -- Correct the heightMaps origin, so it is centered on the x-axis
  local stepsize = math.ceil(MM_TO_PROCESS / pixelSizeY) -- convert mm to pixel steps

  -- Rotate 90° around x axis and translate to the base of the scanned image
  local rectangleBaseTransformation = Transform.createRigidAxisAngle3D({1, 0, 0}, math.pi / 2, 0,
                                                                       MM_TO_PROCESS / 2, minZ + zRange / 2)
  local scanBox = Shape3D.createBox(heightMapW * pixelSizeX, zRange * 1.2, MM_TO_PROCESS, rectangleBaseTransformation)

  -------------------------------------------------
  -- Extract teach profile ------
  -------------------------------------------------

  -- Preprocess profile to teach on
  local profilesToAggregate = {}
  for j = 0, stepsize - 1 do -- stepzie = MM_TO_PROCESS / pixelSizeY
    profilesToAggregate[#profilesToAggregate + 1] =
      Image.extractRowProfile(heightMap, j)
  end
  local frameProfile = Profile.aggregate(profilesToAggregate, 'MEAN')
  frameProfile:convertCoordinateType('EXPLICIT_1D')
  local startProfile = frameProfile:fillInvalidValues('LINEAR')

  -- Extract region to match
  local teachStartInd = 180
  local teachStopInd = 410
  local teachProfile = startProfile:crop(teachStartInd, teachStopInd)

  -------------------------------------------------
  -- Teach profile ------
  -------------------------------------------------

  local matcher = Profile.Matching.PatternMatcher.create()
  matcher:teach(teachProfile)

  -------------------------------------------------
  -- Process data and start over three times ------
  -------------------------------------------------

  for iRepeat = 1, 3 do
    for i = 0, heightMapH - 1, stepsize do
      local profilingTime = DateTime.getTimestamp()

      -------------------------------------------------
      -- Aggregate a number of profiles together ------
      -------------------------------------------------

      profilesToAggregate = {}
      for j = 0, stepsize - 1 do -- stepzie = MM_TO_PROCESS / pixelSizeY
        if i + j < heightMapH then
          profilesToAggregate[#profilesToAggregate + 1] =  Image.extractRowProfile(heightMap, i + j)
        end
      end
      frameProfile = Profile.aggregate(profilesToAggregate, 'MEAN')
      frameProfile:convertCoordinateType('EXPLICIT_1D')

      -------------------------------------------------
      -- Match profiles -
      -------------------------------------------------

      local pos, score = matcher:match(frameProfile)

      -------------------------------------------------
      -- Match OK? -
      -------------------------------------------------
      local validStr
      local failPassColor = RED
      local plotProfile = teachProfile:clone()
      local translation = 0.0
      if score > 0.95 then
        validStr = 'true'
        failPassColor = GREEN
        translation = Profile.getCoordinate(frameProfile, pos) - teachProfile:getCoordinate(0)
      else
        validStr = 'false'
        plotProfile:addConstantInplace(-7) -- Plot not ok match below current profile
      end

      print('')
      print('Valid:  ' .. validStr)
      print('Time for processing: ' .. DateTime.getTimestamp() - profilingTime .. 'ms')

      -------------------------------------------------
      -- Plot results -
      -------------------------------------------------
      local gDeco = View.GraphDecoration.create()
      gDeco:setXBounds(0, 100)
      gDeco:setYBounds(0, 40)
      gDeco:setDrawSize(0.8)

      -- Plot current profile
      v2D:clear()
      v2D:addProfile(frameProfile, gDeco)

      -- Plot teach profile in best match position
      gDeco:setGraphColor(failPassColor[1], failPassColor[2], failPassColor[3])
      gDeco:setBackgroundColor(0, 0, 0, 0)
      gDeco:setGridColor(0, 0, 0, 0)
      plotProfile:translateInplace(translation, 0)
      v2D:addProfile(plotProfile, gDeco)

      local scannedFrame = scanBox:translate(0, i * pixelSizeY, 0) -- move scan box to the current frame

      v3D:clear()
      v3D:addHeightmap(heightMap, deco3D)
      v3D:addShape(scannedFrame, helper.getDeco(failPassColor, 1, 1, FILL_ALPHA))

      v3D:present()
      v2D:present()
      print('Time for processing + visualization: ' .. DateTime.getTimestamp() - profilingTime .. 'ms')

      Script.sleep(DELAY)
    end
  end
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register('Engine.OnStarted', main)

--End of Function and Event Scope--------------------------------------------------
