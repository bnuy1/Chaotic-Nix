{ ... }: let                                                                                             
                                                                                                         
in {                                                                                                     
   imports = [                                                                                           
      ./home_manager.nix
      ./polkit.nix
      ./virtualisation.nix
      ./boot.nix
      ./networking.nix
  ];                                                                                                    
}                                                                                                        
  
