--!strict
local FirstPersonCamera = require(script.Systems.FirstPersonCamera)

-- ตั้งตอนรันเกมเท่านั้น (ถ้าตั้งใน Studio จะเลื่อนกล้อง edit mode ไม่ได้)
workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

FirstPersonCamera.Enable()
