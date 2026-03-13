{ ... }: let                                                                                             
                                                                                                         
in {                                                                                                     
   imports = [                                                                                           
      ./common-user-packages.nix                                                                         
      ./kitty.nix
      ./nixvim/nixvim.nix
  ];                                                                                                    
}                                                                                                        
  
