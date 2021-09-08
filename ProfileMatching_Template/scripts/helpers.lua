local function getDeco(rgba, lineWidth, pointSize, fillAlpha)
  if not rgba[4] then
    rgba[4] = 255
  end

  local deco = View.ShapeDecoration.create()
  deco:setLineColor(rgba[1], rgba[2], rgba[3], rgba[4])
  deco:setFillColor(rgba[1], rgba[2], rgba[3], fillAlpha)
  if lineWidth then
    deco:setLineWidth(lineWidth)
  end
  if pointSize then
    deco:setPointSize(pointSize)
  end
  return deco
end

local helper = {}
helper.getDeco = getDeco

return helper
