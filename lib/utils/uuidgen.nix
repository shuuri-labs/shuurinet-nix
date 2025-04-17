{ pkgs }:
filename:
let
  # make uuidsPath if it doesn't exist
  uuidsPath = builtins.trace "Creating uuids directory" (builtins.mkdir -p  "/var/lib/vm/uuids");
  
  currentUuidPath = uuidsPath + "/" + filename + ".txt";

  # Try to read existing UUID file
  existingUUID = builtins.tryEval (builtins.readFile currentUuidPath);
  
  # Generate new UUID and save it if file doesn't exist
  newUUID = builtins.toString (pkgs.runCommand "generate-uuid" {} ''
    ${pkgs.util-linux}/bin/uuidgen > $out
  '');
  
  # If file doesn't exist or can't be read, write new UUID
  uuid = if existingUUID.success 
    then existingUUID.value
    else builtins.trace "Generated new UUID" (builtins.toFile currentUuidPath newUUID);
in 
  builtins.readFile uuid