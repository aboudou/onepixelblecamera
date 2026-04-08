photoDiodeLength = 4.5;
photoDiodeWidth = 4.0;
photoDiodeHeight = 2;

photoDiodeMaxLength = 5.25;
photoDiodeMaxWidth = 4.3;

bodyLength = 70;
bodyShellWidth = 2;
bodyOuterDiameter = photoDiodeWidth + (bodyShellWidth * 2);

pinholeDiameter = 4.0;
pinholeLength = 0.5;

supportLength = 30;

backOpeningLength = 2;

rotate([180, 0, 0]) {
    translate([0, 0, -bodyLength]) {
        difference() {
            difference() {
                union() {
                // Support
                translate([-(bodyOuterDiameter / 2), 0, 0])
                    cube([bodyOuterDiameter, (bodyOuterDiameter / 2), supportLength]);

                    difference() {
                        // Main body
                        cylinder(h = bodyLength, d = bodyOuterDiameter, center = false, $fn = 64);
                    
                        // Pinhole
                        translate([0, 0, (bodyLength - 2)])
                            cylinder(h = (pinholeLength * 6), d = pinholeDiameter, center = false, $fn = 64);       
                    }
                }

                // Main hole
                translate([-(photoDiodeWidth / 2), -(photoDiodeLength / 2), -pinholeLength])
                    cube([photoDiodeWidth, photoDiodeLength, bodyLength]);
            }
            
            // Photodiode socket
            translate([-(photoDiodeMaxWidth / 2), -(photoDiodeMaxLength / 2), -1])
                cube([photoDiodeMaxWidth, photoDiodeMaxLength, (photoDiodeHeight + backOpeningLength + 1)]);
            
        }
    }
}
