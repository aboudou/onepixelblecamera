// Servo support base
ssBaseWidth = 40;
ssBaseLength = 30;
ssBaseHeight = 5;

// Servo support blocker
ssBlockerWidth = 21;
ssBlockerLength = 17;
ssBlockerHeight = 13;

// Servo support servo
ssServoWidth = 13;
ssServoLength = 23;
ssServoHeight = 15;

// Servo support screw hole
ssScrewHoleDiameter = 1;
ssScrewHoleLength = ssBlockerHeight;

// Main body
mainBodyWidth = 95;
mainBodyLength = ssBaseLength;
mainBodyHeight = 80;

// Feets
footWidth = 10;
footLength = ssBaseLength * 3;
footHeight = 5;

// PCB Perfoboard enclosure
//   PCB is laying on the longest side
boardWidth = 84 + 1; // Real width + margin (a.k.a PCB longest side)
boardLength = 1 + 2 + 1; // Real length + solder + margin (a.k.a PCB width)
boardHeight = 32 + 1; // Real height + margin (a.k.a PCB shortest side)

// Rounding size. Increase sizes by the value, be cautious
roundingSize = 1;


module servoSupport() {
    difference() {
        union() {
            minkowski() {
                cube([ssBaseWidth, ssBaseLength, ssBaseHeight]);
                sphere(roundingSize, $fn = 32);
            }

            difference() {
                translate([(ssBaseWidth - ssBlockerWidth) / 2 , (ssBaseLength - ssBlockerLength), ssBaseHeight]) {
                    minkowski() {
                        cube([ssBlockerWidth, ssBlockerLength, ssBlockerHeight - roundingSize]);
                        sphere(roundingSize, $fn = 32);
                    }
                }
                
                translate([(ssBaseWidth - ssScrewHoleDiameter) / 2 , (ssServoLength + 2 + (ssBaseLength - (ssServoLength + 2)) / 2), ssBaseHeight]) {
                    cylinder(h = ssScrewHoleLength, d = ssScrewHoleDiameter, center = false, $fn = 32);
                }
                
            }
        }
        
        translate([(ssBaseWidth - ssServoWidth) / 2, 2, 2]) {
            cube([ssServoWidth, ssServoLength, ssServoHeight + 2]);
        }
    }
}

module mainBody() {
    cube([mainBodyWidth, mainBodyLength, mainBodyHeight]);
}

module pcbPerfoEnclosure() {

    difference() {
        difference() {
            translate([(mainBodyWidth - (boardWidth + 4)) / 2, -(boardLength + 4), footHeight + 10]) {
                minkowski() {
                    cube([boardWidth + 4, boardLength + 4, boardHeight + 2]);
                    sphere(roundingSize, $fn = 32);
                }
            }
            
            translate([(mainBodyWidth - boardWidth) / 2, -(boardLength + 2), footHeight + 10 + 2]) {
                cube([boardWidth, boardLength, boardHeight + 2]);
            }
        }
        
        translate([(mainBodyWidth - (boardWidth - 3)) / 2, -(boardLength + 5), footHeight + 10 + 4]) {
            cube([boardWidth - 3, boardLength + 2, boardHeight]);
        }
        
    }
}

module feet() {
    translate([10, -(footLength -  mainBodyLength)/ 2, 0]) {
        cube([footWidth, footLength, footHeight]);
    }

    translate([mainBodyWidth - footWidth - 10, -(footLength -  mainBodyLength)/ 2, 0]) {
        cube([footWidth, footLength, footHeight]);
    }
}

difference() {
    union() {
        minkowski() {
            union() {
                mainBody();
                feet();
            }
            sphere(roundingSize, $fn = 32);
        }
            
        pcbPerfoEnclosure();

        translate([(mainBodyWidth - ssBaseWidth) / 2, 0, mainBodyHeight]) {
            servoSupport();
        }
    }
    
    union() {
        translate([mainBodyWidth / 2, mainBodyLength, (mainBodyHeight / 2) + 15]) {
            rotate([90, 0, 180]) {
                linear_extrude(1) {
                    text(text = "One Pixel", size = 10, font = "Liberation Sans", halign = "center");
                }
            }
        }
        translate([mainBodyWidth / 2, mainBodyLength, (mainBodyHeight / 2)]) {
            rotate([90, 0, 180]) {
                linear_extrude(1) {
                    text(text = "BLE", size = 10, font = "Liberation Sans", halign = "center");
                }
            }
        }
        translate([mainBodyWidth / 2, mainBodyLength, (mainBodyHeight / 2) - 15]) {
            rotate([90, 0, 180]) {
                linear_extrude(1) {
                    text(text = "Camera", size = 10, font = "Liberation Sans", halign = "center");
                }
            }
        }
    }

}
