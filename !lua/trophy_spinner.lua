function onCollisionEnter(info)
    local obj = info.collision_object;

      if (obj.interactable and next(self.getJoints()) == nil and obj.TRH_Class == "Trophy") then
          local pos = self.getPosition();

          local set = {
              x = pos.x,
              y = pos.y + 0.5,
              z = pos.z
          }

          obj.setPosition(set)
          obj.setRotation({x=0,y=0,z=0})
          self.jointTo(obj, {
              ["type"]        = "Hinge",
              ["collision"]   = false,
              ["axis"]        = {0,1,0},
              ["anchor"]      = {0,0,0},
              ["motor_force"]  = 50.0,
              ["motor_velocity"] = 50.0,
              ["motor_freeSpin"] = true
          })
      end
end
