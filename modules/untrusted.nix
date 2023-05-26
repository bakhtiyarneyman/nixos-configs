{
  config = {
    users.users =
      let
        hashedPassword = "$6$du.QjcXi8kM4UnuK$IRSujrQ2p8xPAQawatjWypo/OK2Sr3Em5orJYEjTjebzgiIwY4fyubn/F3tRbfzJLjpt9Dp3F/0gSJTN0fyrF/"; in
      {
        root = { inherit hashedPassword; };
        bakhtiyar = { inherit hashedPassword; };
      };
  };
}
