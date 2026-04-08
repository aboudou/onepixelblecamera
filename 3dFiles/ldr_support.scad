ldrDiameter = 5;
ldrHeight = 2;

bodyLength = 70;
bodyShellWidth = 2;
bodyOuterDiameter = ldrDiameter + (bodyShellWidth * 2);

pinholeDiameter = 1.0;
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
                translate([0, 0, -pinholeLength])
                    cylinder(h = bodyLength, d = (ldrDiameter - 0.5), center = false, $fn = 64);
            }
            
            // LDR socket
            translate([0, 0, -1])
                cylinder(h = (ldrHeight + backOpeningLength + 1), d = ldrDiameter, center = false, $fn = 64);
        }
    }
}